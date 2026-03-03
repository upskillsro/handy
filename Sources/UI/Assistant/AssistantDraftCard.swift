import SwiftUI

struct AssistantDraftCard: View {
    let action: AssistantActionDraft
    let onChange: (AssistantActionDraft) -> Void
    let onApply: (AssistantActionDraft) -> Void
    let onDiscard: () -> Void

    @State private var localAction: AssistantActionDraft
    @State private var showDatePopover = false
    @State private var showTimePopover = false
    @State private var showPriorityPopover = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .glass

    init(action: AssistantActionDraft, onChange: @escaping (AssistantActionDraft) -> Void, onApply: @escaping (AssistantActionDraft) -> Void, onDiscard: @escaping () -> Void) {
        self.action = action
        self.onChange = onChange
        self.onApply = onApply
        self.onDiscard = onDiscard
        _localAction = State(initialValue: action)
    }

    private var isWhiteTheme: Bool { appTheme == .white }
    private var isEditableAction: Bool { localAction.kind == .create || localAction.kind == .update }
    private var hasDate: Bool { localAction.schedule?.hasDate ?? false }
    private var hasTime: Bool { localAction.schedule?.hasTime ?? false }
    private var currentPriority: Int { localAction.priority ?? 0 }
    private var cardFillColor: Color {
        switch appTheme {
        case .glass:
            return Color.black.opacity(0.14)
        case .dark:
            return Color.black.opacity(0.26)
        case .white:
            return Color.black.opacity(0.03)
        }
    }
    private var cardStrokeColor: Color {
        isWhiteTheme ? Color.black.opacity(0.07) : Color.white.opacity(0.07)
    }
    private var metaBackground: Color {
        isWhiteTheme ? Color.black.opacity(0.04) : Color.white.opacity(0.04)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditableAction {
                editableContent
            } else if localAction.kind == .reorder {
                reorderContent
            } else if localAction.kind == .complete {
                completionContent
            } else {
                staticSummaryContent
            }

            footerRow
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardStrokeColor, lineWidth: 1)
        )
        .onChange(of: action) { _, newAction in
            localAction = newAction
        }
    }

    private var editableContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if localAction.kind == .update, let target = localAction.targetReminderTitle, !target.isEmpty {
                Text(target)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            TextField("Task title", text: Binding(
                get: { localAction.title ?? "" },
                set: { value in
                    localAction.title = value
                    onChange(localAction)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(GlassyBackground(theme: appTheme))

            HStack(spacing: 8) {
                dateButton
                timeButton
                priorityButton

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if let date = localAction.schedule?.date {
                            metaPill(systemImage: "calendar", text: compactDate(date))
                        }
                        if let time = localAction.schedule?.time, let compactTime = compactTime(time) {
                            metaPill(systemImage: "clock", text: compactTime)
                        }
                        if currentPriority != 0 {
                            metaPill(systemImage: "flag.fill", text: priorityTitle(currentPriority), tint: priorityColor(currentPriority))
                        }
                    }
                    .padding(.trailing, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(metaBackground)
            )
        }
    }

    private var dateButton: some View {
        iconButton(systemImage: "calendar") {
            showDatePopover.toggle()
        }
        .popover(isPresented: $showDatePopover, arrowEdge: .bottom) {
            assistantPopover {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date")
                        .font(.headline)

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { localAction.schedule?.date ?? Calendar.current.startOfDay(for: Date()) },
                            set: { newDate in
                                let existingTime = localAction.schedule?.time
                                localAction.schedule = AssistantScheduleDraft(date: newDate, time: existingTime)
                                onChange(localAction)
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)

                    HStack {
                        Button("Clear") {
                            localAction.schedule = .empty
                            onChange(localAction)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Done") {
                            showDatePopover = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var timeButton: some View {
        iconButton(systemImage: "clock") {
            if !hasDate {
                localAction.schedule = AssistantScheduleDraft(date: Calendar.current.startOfDay(for: Date()), time: localAction.schedule?.time)
                onChange(localAction)
            }
            showTimePopover.toggle()
        }
        .popover(isPresented: $showTimePopover, arrowEdge: .bottom) {
            assistantPopover {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time")
                        .font(.headline)

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { resolvedPopoverTimeDate() },
                            set: { newValue in
                                let time = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                let existingDate = localAction.schedule?.date ?? Calendar.current.startOfDay(for: Date())
                                localAction.schedule = AssistantScheduleDraft(date: existingDate, time: time)
                                onChange(localAction)
                            }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)

                    HStack {
                        Button("Clear") {
                            let existingDate = localAction.schedule?.date
                            localAction.schedule = existingDate.map { AssistantScheduleDraft(date: $0, time: nil) } ?? .empty
                            onChange(localAction)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Done") {
                            showTimePopover = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var priorityButton: some View {
        iconButton(systemImage: "flag") {
            showPriorityPopover.toggle()
        }
        .popover(isPresented: $showPriorityPopover, arrowEdge: .bottom) {
            assistantPopover {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Priority")
                        .font(.headline)

                    ReminderPriorityChips(
                        theme: appTheme,
                        selectedPriority: Binding(
                            get: { currentPriority },
                            set: { newValue in
                                localAction.priority = newValue == 0 ? nil : newValue
                                onChange(localAction)
                            }
                        )
                    )

                    HStack {
                        Spacer()
                        Button("Done") {
                            showPriorityPopover = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var reorderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localAction.targetReminderTitle ?? localAction.displayTitle)
                .font(.system(size: 14, weight: .medium))

            Stepper(value: Binding(
                get: { max(localAction.newPosition ?? 1, 1) },
                set: { value in
                    localAction.newPosition = max(value, 1)
                    onChange(localAction)
                }
            ), in: 1...999) {
                Text("Move to position \(localAction.newPosition ?? 1)")
                    .font(.caption)
            }
        }
    }

    private var completionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localAction.targetReminderTitle ?? localAction.displayTitle)
                .font(.system(size: 14, weight: .medium))

            Toggle(isOn: Binding(
                get: { localAction.completed ?? true },
                set: { value in
                    localAction.completed = value
                    onChange(localAction)
                }
            )) {
                Text((localAction.completed ?? true) ? "Mark complete" : "Mark incomplete")
                    .font(.caption)
            }
            .toggleStyle(.switch)
        }
    }

    private var staticSummaryContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localAction.targetReminderTitle ?? localAction.displayTitle)
                .font(.system(size: 14, weight: .medium))
            Text(localAction.summaryText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var footerRow: some View {
        HStack {
            Button("Discard", action: onDiscard)
                .buttonStyle(.borderless)
                .font(.caption)

            Spacer()

            Button(buttonTitle(for: localAction.kind)) {
                onApply(localAction)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isWhiteTheme ? .primary : .white.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isWhiteTheme ? Color.black.opacity(0.05) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private func assistantPopover<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(width: 250)
    }

    private func metaPill(systemImage: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(tint ?? (isWhiteTheme ? .primary : .white.opacity(0.86)))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((tint ?? (isWhiteTheme ? Color.black.opacity(0.05) : Color.white.opacity(0.08))).opacity(tint == nil ? 1 : 0.16))
        )
    }

    private func resolvedPopoverTimeDate() -> Date {
        let baseDate = localAction.schedule?.date ?? Calendar.current.startOfDay(for: Date())
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = localAction.schedule?.time?.hour ?? Calendar.current.component(.hour, from: Date())
        components.minute = localAction.schedule?.time?.minute ?? Calendar.current.component(.minute, from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }

    private func compactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func compactTime(_ time: DateComponents) -> String? {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = time.hour
        components.minute = time.minute
        guard let date = Calendar.current.date(from: components) else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func priorityTitle(_ priority: Int) -> String {
        switch priority {
        case 1...4: return "High"
        case 5: return "Medium"
        case 6...9: return "Low"
        default: return "None"
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1...4: return .red
        case 5: return .orange
        case 6...9: return .blue
        default: return .secondary
        }
    }

    private func buttonTitle(for kind: AssistantActionKind) -> String {
        switch kind {
        case .create: return "Create"
        case .update: return "Apply"
        case .delete: return "Delete"
        case .complete: return "Apply"
        case .reorder: return "Move"
        }
    }
}
