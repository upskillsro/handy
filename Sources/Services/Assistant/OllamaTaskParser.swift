import Foundation

struct OllamaTaskParser {
    let client: OllamaClient
    let model: String
    let maxDrafts: Int

    func parseActions(from sourceText: String, reminders: [AssistantReminderContext]) async throws -> AssistantSuggestionBatch {
        do {
            return try await parseSingleActionPass(from: sourceText, reminders: reminders, maxActions: maxDrafts)
        } catch AssistantError.noTasksDetected {
            let fallback = try await parseFallbackClausePass(from: sourceText, reminders: reminders)
            guard !fallback.actions.isEmpty else { throw AssistantError.noTasksDetected }
            return fallback
        } catch AssistantError.invalidModelResponse {
            let fallback = try await parseFallbackClausePass(from: sourceText, reminders: reminders)
            guard !fallback.actions.isEmpty else { throw AssistantError.invalidModelResponse }
            return fallback
        }
    }

    private func parseSingleActionPass(from sourceText: String, reminders: [AssistantReminderContext], maxActions: Int) async throws -> AssistantSuggestionBatch {
        let now = ISO8601DateFormatter().string(from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = .current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = .current
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = .current

        let reminderContext = reminders.map { reminder in
            let dueDate = reminder.dueDate.map { dateFormatter.string(from: $0) } ?? "null"
            let dueTime = reminder.dueDate.flatMap { dateHasMeaningfulTime($0) ? timeFormatter.string(from: $0) : nil } ?? "null"
            return """
            {"id":"\(reminder.id)","title":"\(escapeJSONString(reminder.title))","due_date":\(dueDate == "null" ? "null" : "\"\(dueDate)\""),"due_time":\(dueTime == "null" ? "null" : "\"\(dueTime)\""),"priority":\(reminder.priority),"completed":\(reminder.isCompleted),"position":\(reminder.position)}
            """
        }.joined(separator: ",")

        let systemPrompt = """
        You help manage Apple Reminders for a local desktop app.
        Return only valid JSON using this schema:
        {
          "actions": [
            {
              "action": "create|update|delete|complete|reorder",
              "target_id": "existing reminder id or null",
              "target_title": "existing reminder title or null",
              "title": "new title for create/update or null",
              "due_date": "YYYY-MM-DD or null",
              "due_time": "HH:mm or null",
              "priority": "none|low|medium|high or null",
              "new_position": "1-based integer or null",
              "completed": "true|false|null"
            }
          ]
        }
        Rules:
        - Return at most \(maxActions) actions.
        - Use exact target_id values from the provided reminders when modifying, deleting, completing, or reordering existing reminders.
        - Never invent target_id values.
        - Prefer create when no confident existing reminder match exists.
        - The current local date/time is \(now). Resolve relative dates like "tomorrow" or "Friday" against this value.
        - Never invent a past year. If the date is unclear, use null.
        - Date and time are separate fields.
        - If the user specifies a date but not a time, set due_date and keep due_time null.
        - If the user does not explicitly specify a time, due_time must be null.
        - Never infer times from task type or words like "schedule", "next", "today", "tomorrow", or "this week".
        - If a time appears without a usable date, return due_date = null and due_time = null.
        - A shared phrase like "for today", "today I need to", or "add these tasks for tomorrow" applies to every created task in the same list unless explicitly overridden.
        - Do not assign different dates to sibling tasks unless the prompt explicitly distinguishes them.
        - Use action=update only when changing title, due_date, or priority on an existing reminder.
        - Use action=delete to remove an existing reminder.
        - Use action=complete when the user asks to finish or reopen a reminder. Set completed to true or false.
        - Use action=reorder only when the user explicitly asks to move, reorder, push up/down, or make something first/last.
        - Set new_position only for reorder actions. Otherwise use null.
        - Set priority only when the user explicitly implies urgency or importance. Otherwise use null.
        - Do not assign both reorder and unrelated updates to the same action.
        - Do not include explanations or markdown.

        Current reminders:
        [\(reminderContext)]
        """

        let rawResponse = try await client.chat(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: sourceText)
            ]
        )

        if let batch = decodeBatch(from: rawResponse) {
            return try finalize(batch: batch, sourceText: sourceText, reminders: reminders, maxActions: maxActions)
        }

        AppLogger.ollama.error("Initial Ollama response could not be decoded as JSON.")

        let repairPrompt = """
        Rewrite the following content as valid JSON only. Use this schema exactly:
        {"actions":[{"action":"create|update|delete|complete|reorder","target_id":"string or null","target_title":"string or null","title":"string or null","due_date":"YYYY-MM-DD or null","due_time":"HH:mm or null","priority":"none|low|medium|high or null","new_position":"integer or null","completed":"true|false|null"}]}
        Content:
        \(rawResponse)
        """

        let repairedResponse = try await client.chat(
            model: model,
            messages: [
                .init(role: "system", content: "Return valid JSON only."),
                .init(role: "user", content: repairPrompt)
            ]
        )

        guard let repairedBatch = decodeBatch(from: repairedResponse) else {
            throw AssistantError.invalidModelResponse
        }

        return try finalize(batch: repairedBatch, sourceText: sourceText, reminders: reminders, maxActions: maxActions)
    }

    private func parseFallbackClausePass(from sourceText: String, reminders: [AssistantReminderContext]) async throws -> AssistantSuggestionBatch {
        let clauses = fallbackClauses(from: sourceText)
        guard clauses.count > 1 else { throw AssistantError.noTasksDetected }

        var merged: [AssistantActionDraft] = []
        for clause in clauses.prefix(maxDrafts) {
            do {
                let batch = try await parseSingleActionPass(from: clause, reminders: reminders, maxActions: 1)
                for action in batch.actions where !merged.contains(action) {
                    merged.append(action)
                }
            } catch {
                continue
            }
        }

        guard !merged.isEmpty else {
            throw AssistantError.noTasksDetected
        }
        return AssistantSuggestionBatch(sourceText: sourceText, actions: Array(merged.prefix(maxDrafts)))
    }

    private func finalize(batch: ParsedAssistantActionBatch, sourceText: String, reminders: [AssistantReminderContext], maxActions: Int) throws -> AssistantSuggestionBatch {
        let normalized = AssistantActionNormalizer.normalize(batch: batch, sourceText: sourceText, reminders: reminders, maxActions: maxActions)
        guard !normalized.actions.isEmpty else {
            throw AssistantError.noTasksDetected
        }
        return normalized
    }

    private func decodeBatch(from rawResponse: String) -> ParsedAssistantActionBatch? {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String

        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            candidate = String(trimmed[start...end])
        } else {
            candidate = trimmed
        }

        guard let data = candidate.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedAssistantActionBatch.self, from: data)
    }

    private func escapeJSONString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func fallbackClauses(from sourceText: String) -> [String] {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = globalSchedulingPrefix(from: trimmed)
        let body = trimmed
            .replacingOccurrences(of: prefix, with: "", options: [.caseInsensitive, .anchored])
            .trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))

        let clauses = body
            .replacingOccurrences(of: ";", with: ",")
            .components(separatedBy: ",")
            .flatMap { segment in
                segment.components(separatedBy: " and ")
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !prefix.isEmpty else { return clauses }
        return clauses.map { "\(prefix): \($0)" }
    }

    private func globalSchedulingPrefix(from sourceText: String) -> String {
        let lowercased = sourceText.lowercased()
        let patterns = [
            "for today",
            "today i need to",
            "today:",
            "for tomorrow",
            "tomorrow i need to",
            "tomorrow:"
        ]

        if let pattern = patterns.first(where: { lowercased.contains($0) }),
           let range = lowercased.range(of: pattern) {
            let prefix = sourceText[..<range.upperBound]
            return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let colonIndex = sourceText.firstIndex(of: ":") {
            let prefix = String(sourceText[..<colonIndex])
            let lowercasedPrefix = prefix.lowercased()
            if lowercasedPrefix.contains("today") || lowercasedPrefix.contains("tomorrow") {
                return prefix
            }
        }

        return ""
    }

    private func dateHasMeaningfulTime(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
    }
}
