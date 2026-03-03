import Foundation

struct AssistantScheduleDraft: Equatable, Codable {
    var date: Date?
    var time: DateComponents?

    init(date: Date? = nil, time: DateComponents? = nil) {
        self.date = date.map { Calendar.current.startOfDay(for: $0) }
        self.time = Self.normalizedTime(from: time)
    }

    var hasDate: Bool { date != nil }
    var hasTime: Bool { time?.hour != nil || time?.minute != nil }
    var isEmpty: Bool { !hasDate && !hasTime }

    func resolvedDateComponents(calendar: Calendar = .current) -> DateComponents? {
        guard let date else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        if let hour = time?.hour {
            components.hour = hour
        }
        if let minute = time?.minute {
            components.minute = minute
        }
        return components
    }

    func resolvedDate(calendar: Calendar = .current) -> Date? {
        guard let components = resolvedDateComponents(calendar: calendar) else { return nil }
        return calendar.date(from: components)
    }

    func withDate(_ date: Date?) -> AssistantScheduleDraft {
        guard let date else { return AssistantScheduleDraft() }
        return AssistantScheduleDraft(date: date, time: time)
    }

    func withTime(_ time: DateComponents?) -> AssistantScheduleDraft {
        AssistantScheduleDraft(date: date, time: time)
    }

    static let empty = AssistantScheduleDraft()

    private static func normalizedTime(from time: DateComponents?) -> DateComponents? {
        let hour = time?.hour
        let minute = time?.minute
        guard hour != nil || minute != nil else { return nil }
        var components = DateComponents()
        components.hour = hour ?? 0
        components.minute = minute ?? 0
        return components
    }
}

struct TaskDraft: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var schedule: AssistantScheduleDraft
    var priority: Int

    init(id: UUID = UUID(), title: String, schedule: AssistantScheduleDraft = .empty, priority: Int = 0) {
        self.id = id
        self.title = title
        self.schedule = schedule
        self.priority = priority
    }
}

enum AssistantActionKind: String, Codable, Equatable, CaseIterable {
    case create
    case update
    case delete
    case complete
    case reorder
}

struct AssistantReminderContext: Equatable, Codable {
    var id: String
    var title: String
    var dueDate: Date?
    var priority: Int
    var isCompleted: Bool
    var position: Int
}

struct AssistantActionDraft: Identifiable, Equatable {
    var id: UUID
    var kind: AssistantActionKind
    var targetReminderId: String?
    var targetReminderTitle: String?
    var title: String?
    var schedule: AssistantScheduleDraft?
    var priority: Int?
    var newPosition: Int?
    var completed: Bool?

    init(
        id: UUID = UUID(),
        kind: AssistantActionKind,
        targetReminderId: String? = nil,
        targetReminderTitle: String? = nil,
        title: String? = nil,
        schedule: AssistantScheduleDraft? = nil,
        priority: Int? = nil,
        newPosition: Int? = nil,
        completed: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.targetReminderId = targetReminderId
        self.targetReminderTitle = targetReminderTitle
        self.title = title
        self.schedule = schedule
        self.priority = priority
        self.newPosition = newPosition
        self.completed = completed
    }

    var displayTitle: String {
        switch kind {
        case .create:
            return title ?? "New task"
        case .update:
            return targetReminderTitle ?? title ?? "Update task"
        case .delete:
            return targetReminderTitle ?? "Delete task"
        case .complete:
            return targetReminderTitle ?? "Complete task"
        case .reorder:
            return targetReminderTitle ?? "Reorder task"
        }
    }

    var summaryText: String {
        switch kind {
        case .create:
            return "Create a new reminder"
        case .update:
            return "Modify an existing reminder"
        case .delete:
            return "Delete the matched reminder"
        case .complete:
            return (completed ?? true) ? "Mark the reminder complete" : "Mark the reminder incomplete"
        case .reorder:
            if let newPosition {
                return "Move this reminder to position \(newPosition)"
            }
            return "Reorder this reminder"
        }
    }
}

struct AssistantSuggestionBatch: Equatable {
    var sourceText: String
    var actions: [AssistantActionDraft]
}

enum AssistantState: Equatable {
    case idle
    case recording
    case transcribing(audioFileURL: URL)
    case generating(transcript: String)
    case review(AssistantSuggestionBatch)
    case error(AssistantError)
}

enum AssistantError: Error, Equatable, LocalizedError {
    case microphonePermissionDenied
    case recordingFailed(String)
    case transcriptionNotConfigured
    case transcriptionCommandNotFound
    case transcriptionFailed(String)
    case ollamaUnavailable
    case modelNotInstalled
    case invalidModelResponse
    case noTasksDetected
    case actionTargetNotFound(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record audio."
        case .recordingFailed(let message):
            return message
        case .transcriptionNotConfigured:
            return "Set a local transcription command in Assistant settings to use voice input."
        case .transcriptionCommandNotFound:
            return "The configured transcription command could not be found."
        case .transcriptionFailed(let message):
            return message
        case .ollamaUnavailable:
            return "Helpy could not reach Ollama on localhost."
        case .modelNotInstalled:
            return "The configured Ollama model is not installed."
        case .invalidModelResponse:
            return "The local model returned an invalid action format."
        case .noTasksDetected:
            return "No actionable task changes were detected."
        case .actionTargetNotFound(let title):
            return "Helpy could not find the reminder \"\(title)\"."
        }
    }
}

struct ParsedAssistantAction: Codable, Equatable {
    var action: String
    var targetId: String?
    var targetTitle: String?
    var title: String?
    var dueDate: String?
    var dueTime: String?
    var priority: String?
    var newPosition: Int?
    var completed: Bool?
    var scheduleFieldsWereProvided: Bool = false

    enum CodingKeys: String, CodingKey {
        case action
        case targetId = "target_id"
        case targetTitle = "target_title"
        case title
        case dueDate = "due_date"
        case dueTime = "due_time"
        case priority
        case newPosition = "new_position"
        case completed
    }

    init(action: String, targetId: String?, targetTitle: String?, title: String?, dueDate: String?, dueTime: String? = nil, priority: String?, newPosition: Int?, completed: Bool?, scheduleFieldsWereProvided: Bool = false) {
        self.action = action
        self.targetId = targetId
        self.targetTitle = targetTitle
        self.title = title
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.priority = priority
        self.newPosition = newPosition
        self.completed = completed
        self.scheduleFieldsWereProvided = scheduleFieldsWereProvided
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = (try? container.decode(String.self, forKey: .action)) ?? ""
        targetId = try? container.decodeIfPresent(String.self, forKey: .targetId)
        targetTitle = try? container.decodeIfPresent(String.self, forKey: .targetTitle)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        dueDate = try? container.decodeIfPresent(String.self, forKey: .dueDate)
        dueTime = try? container.decodeIfPresent(String.self, forKey: .dueTime)
        scheduleFieldsWereProvided = container.contains(.dueDate) || container.contains(.dueTime)

        if let stringPriority = try? container.decodeIfPresent(String.self, forKey: .priority) {
            priority = stringPriority
        } else if let intPriority = try? container.decodeIfPresent(Int.self, forKey: .priority) {
            priority = "\(intPriority)"
        } else {
            priority = nil
        }

        if let position = try? container.decodeIfPresent(Int.self, forKey: .newPosition) {
            newPosition = position
        } else if let stringPosition = try? container.decodeIfPresent(String.self, forKey: .newPosition), let position = Int(stringPosition) {
            newPosition = position
        } else {
            newPosition = nil
        }

        if let boolCompleted = try? container.decodeIfPresent(Bool.self, forKey: .completed) {
            completed = boolCompleted
        } else if let stringCompleted = try? container.decodeIfPresent(String.self, forKey: .completed) {
            completed = Bool(stringCompleted)
        } else {
            completed = nil
        }
    }
}

struct ParsedAssistantActionBatch: Codable, Equatable {
    var actions: [ParsedAssistantAction]
}

enum AssistantPriorityMapper {
    static func normalize(_ priority: String?) -> Int {
        switch priority?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "high":
            return 1
        case "medium":
            return 5
        case "low":
            return 9
        default:
            return 0
        }
    }
}

enum AssistantActionNormalizer {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    static func normalize(batch: ParsedAssistantActionBatch, sourceText: String, reminders: [AssistantReminderContext], maxActions: Int) -> AssistantSuggestionBatch {
        let reminderTitleById = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id, $0.title) })
        let actions = batch.actions.prefix(maxActions).compactMap { action -> AssistantActionDraft? in
            guard var kind = AssistantActionKind(rawValue: action.action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
                return nil
            }

            let title = action.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetTitle = action.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let schedule = normalizedSchedule(from: action)
            let priority = action.priority.map(AssistantPriorityMapper.normalize(_:))
            let normalizedTargetId = action.targetId?.trimmingCharacters(in: .whitespacesAndNewlines)

            if kind == .create, let normalizedTargetId, let existingTitle = reminderTitleById[normalizedTargetId], let title, title.caseInsensitiveCompare(existingTitle) != .orderedSame {
                kind = .update
            }

            switch kind {
            case .create:
                guard let title, !title.isEmpty else { return nil }
                return AssistantActionDraft(
                    kind: .create,
                    title: title,
                    schedule: schedule,
                    priority: priority == 0 ? nil : priority
                )
            case .update, .delete, .complete, .reorder:
                guard let targetId = normalizedTargetId, !targetId.isEmpty else { return nil }
                if kind == .update {
                    let hasMutation = (title?.isEmpty == false) || schedule != nil || priority != nil
                    guard hasMutation else { return nil }
                }
                if kind == .reorder {
                    guard let newPosition = action.newPosition, newPosition > 0 else { return nil }
                    return AssistantActionDraft(
                        kind: kind,
                        targetReminderId: targetId,
                        targetReminderTitle: targetTitle,
                        title: title,
                        schedule: schedule,
                        priority: priority == 0 ? nil : priority,
                        newPosition: newPosition,
                        completed: action.completed
                    )
                }
                return AssistantActionDraft(
                    kind: kind,
                    targetReminderId: targetId,
                    targetReminderTitle: targetTitle,
                    title: title,
                    schedule: schedule,
                    priority: priority == 0 ? nil : priority,
                    newPosition: action.newPosition,
                    completed: action.completed
                )
            }
        }

        return AssistantSuggestionBatch(sourceText: sourceText, actions: Array(actions))
    }

    private static func normalizedSchedule(from action: ParsedAssistantAction) -> AssistantScheduleDraft? {
        let date = action.dueDate
            .flatMap { dateFormatter.date(from: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .map { Calendar.current.startOfDay(for: $0) }

        let time = parseTimeComponents(action.dueTime)

        if let date {
            return AssistantScheduleDraft(date: date, time: time)
        }

        if action.scheduleFieldsWereProvided {
            return .empty
        }

        return nil
    }

    private static func parseTimeComponents(_ rawTime: String?) -> DateComponents? {
        guard let rawTime = rawTime?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTime.isEmpty else { return nil }

        let pieces = rawTime.split(separator: ":")
        guard pieces.count == 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }
}
