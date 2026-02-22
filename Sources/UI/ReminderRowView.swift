import SwiftUI
import EventKit
import AppKit

struct ReminderRowView: View, Equatable {
    let reminder: EKReminder
    var isDraggingAppWide: Bool = false
    var isBeingDragged: Bool = false
    
    @EnvironmentObject var remindersService: RemindersService
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var estimateStore: EstimateStore
    
    @State private var isHovering = false
    @State private var showCalendarEdit = false
    @State private var showNotesEdit = false
    @State private var showTimeEdit = false
    @State private var showEstimateEdit = false
    @State private var showMoreActions = false // New state for hover menu
    @State private var isCompleting = false
    
    @AppStorage("appTheme") private var appTheme: AppTheme = .glass
    
    private var effectiveHover: Bool {
        return isHovering && !isDraggingAppWide
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Checkbox
                Button(action: {
                    if !reminder.isCompleted {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isCompleting = true
                        }
                        NSSound(named: "Glass")?.play()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            remindersService.toggleComplete(reminder)
                        }
                    } else {
                        remindersService.toggleComplete(reminder)
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(reminder.priority > 0 ? priorityColor(for: reminder.priority) : Color.secondary, lineWidth: 1.5)
                            .frame(width: 14, height: 14) // Reduced from default (approx 18->14 is ~80%)
                        
                        if isCompleting {
                             Circle()
                                .fill(reminder.priority > 0 ? priorityColor(for: reminder.priority) : Color.secondary)
                                .frame(width: 10, height: 10)
                        }
                        
                        // Particle Effects
                        ParticleEffectView(trigger: $isCompleting)
                    }
                    .frame(width: 16, height: 16) // Touch target
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .strikethrough(reminder.isCompleted)
                        .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                        .font(.system(size: 13, weight: .regular))
                    
                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes.components(separatedBy: .newlines).first ?? "")
                            .lineLimit(1)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .layoutPriority(1)
                
                Spacer()
                
                // Normal State (Meta) - Always present in layout
                HStack(spacing: 8) {
                    if let dueMsg = formatDueTime(reminder.dueDateComponents) {
                        Text(dueMsg)
                            .font(.system(size: 12))
                            .foregroundColor(isOverdue(reminder.dueDateComponents) ? .red : .gray)
                            .fixedSize()
                    }
                    
                    if let _ = reminder.recurrenceRules?.first {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    if reminder.priority > 0 {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12))
                            .foregroundColor(priorityColor(for: reminder.priority))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .trailing) {
                let isEditing = showEstimateEdit || showNotesEdit || showTimeEdit || showMoreActions || showCalendarEdit
                let showActions = (effectiveHover && !reminder.isCompleted) || isEditing
                
                if showActions {
                    HStack(spacing: 0) {
                        // Gradient Mask to fade out content behind
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.0),
                                Color(red: 0.11, green: 0.11, blue: 0.12).opacity(appTheme == .glass ? 0.95 : 1.0),
                                Color(red: 0.11, green: 0.11, blue: 0.12).opacity(appTheme == .glass ? 0.95 : 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 40) // Reduced width slightly for sharper transition
                        .frame(maxHeight: .infinity)
                        
                        HStack(spacing: 12) {
                            // Play
                            Button(action: {
                                let duration = estimateStore.getMetadata(for: reminder.calendarItemIdentifier)?.estimatedDuration ?? 0
                                timerService.startTimer(reminderId: reminder.calendarItemIdentifier, duration: duration)
                            }) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                            .help("Start Timer")
                            
                            // Time/Est Group
                            TaskStatsView(
                                estimates: estimateStore.getEstimates(for: reminder.calendarItemIdentifier),
                                showTimeEdit: $showTimeEdit,
                                showEstimateEdit: $showEstimateEdit,
                                reminder: reminder
                            )
                            
                            // Notes
                            Button(action: { withAnimation { showNotesEdit.toggle() } }) {
                                Image(systemName: (reminder.notes?.isEmpty ?? true) ? "doc" : "doc.text.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor((reminder.notes?.isEmpty ?? true) ? .secondary : .white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            
                            // Trash
                            Button(action: { remindersService.deleteReminder(reminder) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            // --- 3 DOTS MENU ---
                            Button(action: { showMoreActions.toggle() }) {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showMoreActions, arrowEdge: .bottom) {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Schedule Option
                                    Button(action: {
                                        showMoreActions = false
                                        withAnimation { showCalendarEdit = true }
                                    }) {
                                        HStack {
                                            Image(systemName: "calendar")
                                            Text("Schedule")
                                        }
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                    
                                    // Priority Option (Sub-menu simulation)
                                    Text("Priority")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                    
                                    HStack(spacing: 8) {
                                        Button(action: { remindersService.updatePriority(reminder, priority: 0) }) {
                                            Image(systemName: "flag.slash")
                                        }
                                        .help("None")
                                        
                                        Button(action: { remindersService.updatePriority(reminder, priority: 9) }) { // Low
                                            Text("!")
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                        }
                                        .help("Low")
                                        
                                        Button(action: { remindersService.updatePriority(reminder, priority: 5) }) { // Med
                                            Text("!!")
                                                .fontWeight(.bold)
                                                .foregroundColor(.orange)
                                        }
                                        .help("Medium")
                                        
                                        Button(action: { remindersService.updatePriority(reminder, priority: 1) }) { // High
                                            Text("!!!")
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)
                                        }
                                        .help("High")
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 4)
                                }
                                .padding(10)
                                .frame(width: 140)
                            }
                        }
                        .padding(.trailing, 16)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(appTheme == .glass ? 0.95 : 1.0))
                    }
                    .frame(maxHeight: .infinity) 
                }
            }
            
            // Embedded Editors... (Keep existing code)
            
            if showCalendarEdit {
                Divider().background(Color.white.opacity(0.1))
                VStack(spacing: 12) {
                    HStack {
                        // Date Group
                        HStack(spacing: 6) {
                            Text("Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: Binding(
                                get: { reminder.dueDateComponents?.date ?? Date() },
                                set: { remindersService.updateDueDate(reminder, date: $0) }
                            ), displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .frame(minWidth: 100)
                            .fixedSize()
                        }
                        
                        TextFieldSpacer() // 12px Spacer
                        
                        // Time Group
                        HStack(spacing: 6) {
                            Text("Time")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            DatePicker("", selection: Binding(
                                get: { reminder.dueDateComponents?.date ?? Date() },
                                set: { remindersService.updateDueDate(reminder, date: $0) }
                            ), displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .frame(minWidth: 70)
                            .fixedSize()
                        }
                        
                        Spacer()
                    }
                    
                    // Repeat Group
                    HStack(spacing: 6) {
                         Text("Repeat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            Button("Never") { remindersService.updateRecurrence(reminder, frequency: nil) }
                            Divider()
                            Button("Daily") { remindersService.updateRecurrence(reminder, frequency: .daily) }
                            Button("Weekly") { remindersService.updateRecurrence(reminder, frequency: .weekly) }
                            Button("Monthly") { remindersService.updateRecurrence(reminder, frequency: .monthly) }
                            Button("Yearly") { remindersService.updateRecurrence(reminder, frequency: .yearly) }
                        } label: {
                            // Standard look
                            Text(formatRecurrence(reminder.recurrenceRules?.first))
                        }
                        .menuStyle(.borderedButton)
                        .fixedSize()
                        
                        Spacer()
                    }
                    
                    // Button Row (Done & Clear)
                    HStack {
                        Button("Clear") {
                             remindersService.updateDueDate(reminder, date: nil)
                             remindersService.updateRecurrence(reminder, frequency: nil)
                             withAnimation { showCalendarEdit = false }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Button("Done") {
                             withAnimation { showCalendarEdit = false }
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent) // Make Done prominent
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
            }
            
            if showNotesEdit {
                Divider().background(Color.white.opacity(0.1))
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: Binding(
                        get: { reminder.notes ?? "" },
                        set: { remindersService.updateNotes(reminder, newNotes: $0) }
                    ))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 80)
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(appTheme == .glass ? 0.25 : 1.0))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                // Hover Glow Effect (Colored based on priority)
                .shadow(color: effectiveHover ? priorityColor(for: reminder.priority).opacity(0.25) : Color.clear, radius: 8, x: 0, y: 0)
                .drawingGroup() // Optimization: Offload shadow rendering to GPU
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            // Left: Priority Color (Stronger on hover)
                            priorityColor(for: reminder.priority).opacity(effectiveHover ? 0.6 : 0.4),
                            // Right: Fades to almost transparent/subtle
                            priorityColor(for: reminder.priority).opacity(effectiveHover ? 0.1 : 0.05)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hover
            }
        }
        .opacity(isCompleting ? 0.0 : 1.0)
    }
    
    func formatTimeDisplay(spent: TimeInterval, est: TimeInterval) -> String {
        let spentStr = spent > 0 ? formatCompact(spent) : "0m"
        let estStr = est > 0 ? formatCompact(est) : "0m" // Default if unset? Or just "Est"
        // If nothing set, show "Set Est"
        if spent == 0 && est == 0 { return "0m / 0m" } // Placeholder
        return "\(spentStr) / \(estStr)"
    }
    
    func formatCompact(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 {
             let remM = m % 60
             return remM > 0 ? "\(h)h \(remM)m" : "\(h)h"
        }
        return "\(m)m"
    }

    func formatDueTime(_ components: DateComponents?) -> String? {
        guard let _ = components?.hour, let _ = components?.minute else { return nil }
        let date = Calendar.current.date(from: components!) ?? Date()
        return CachedFormatters.shortTime.string(from: date)
    }
    
    func isOverdue(_ components: DateComponents?) -> Bool {
        guard let date = components?.date else { return false }
        return date < Date()
    }
    
    func addEstimate(_ seconds: TimeInterval) {
        let current = estimateStore.getMetadata(for: reminder.calendarItemIdentifier)?.estimatedDuration ?? 0
        estimateStore.updateEstimate(for: reminder.calendarItemIdentifier, duration: current + seconds)
    }
    
    func setEstimate(_ seconds: TimeInterval) {
        estimateStore.updateEstimate(for: reminder.calendarItemIdentifier, duration: seconds)
    }
    
    func addTime(_ seconds: TimeInterval) {
        let current = estimateStore.getMetadata(for: reminder.calendarItemIdentifier)?.timeSpent ?? 0
        // Ensure non-negative
        let newTime = max(0, current + seconds)
        estimateStore.setTimeSpent(for: reminder.calendarItemIdentifier, seconds: newTime)
    }
    
    func setTime(_ seconds: TimeInterval) {
        estimateStore.setTimeSpent(for: reminder.calendarItemIdentifier, seconds: seconds)
    }
    
    func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds == 0 { return "Set Est." }
        let m = Int(seconds) / 60
        let h = m / 60
        
        if h > 0 {
            let remM = m % 60
            return remM > 0 ? "\(h)h \(remM)m" : "\(h)h"
        } else {
            // Less than 1 hour
            if m > 0 {
                return "\(m)m"
            } else {
                // Less than 1 minute (show seconds)
                return "\(Int(seconds))s"
            }
            }
        }

    
    func prioritySymbol(for priority: Int) -> String {
        switch priority {
        case 1...4: return "!!!"
        case 5: return "!!"
        case 6...9: return "!"
        default: return ""
        }
    }
    
    func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1...4: return .red
        case 5: return .orange
        case 6...9: return .blue
        default: return .gray
        }
    }
    
    func formatRecurrence(_ rule: EKRecurrenceRule?) -> String {
        guard let rule = rule else { return "Never" }
        switch rule.frequency {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        @unknown default: return "Custom"
        }
    }
    
    static func == (lhs: ReminderRowView, rhs: ReminderRowView) -> Bool {
        return lhs.reminder.calendarItemIdentifier == rhs.reminder.calendarItemIdentifier &&
               lhs.reminder.isCompleted == rhs.reminder.isCompleted &&
               lhs.reminder.title == rhs.reminder.title &&
               lhs.reminder.notes == rhs.reminder.notes &&
               lhs.reminder.priority == rhs.reminder.priority &&
               lhs.reminder.dueDateComponents == rhs.reminder.dueDateComponents &&
               lhs.isDraggingAppWide == rhs.isDraggingAppWide &&
               lhs.isBeingDragged == rhs.isBeingDragged
    }
}

// MARK: - Subviews

struct TaskStatsView: View {
    @ObservedObject var estimates: EstimateStore.TaskEstimates
    @Binding var showTimeEdit: Bool
    @Binding var showEstimateEdit: Bool
    
    // We pass the popover content builders or just bind the state?
    // The popovers are presented by the PARENT view (ReminderRowView) usually, or we can move them here.
    // If we move popovers here, we need the reminder object.
    let reminder: EKReminder
    
    var body: some View {
        HStack(spacing: 4) {
            // Time Spent Button
            Button(action: { showTimeEdit.toggle() }) {
                let spentText = estimates.timeSpent > 0 ? formatCompact(estimates.timeSpent) : "0m"
                Text(spentText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTimeEdit) {
                TimeSpentPopover(reminder: reminder, estimates: estimates)
            }
            
            // Divider /
            Text("/")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary.opacity(0.5))
                .fixedSize()
            
            // Estimate Button
            Button(action: { showEstimateEdit.toggle() }) {
                let estText = estimates.estimatedDuration > 0 ? formatCompact(estimates.estimatedDuration) : "0m"
                Text(estText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showEstimateEdit) {
                EstimatePopover(reminder: reminder, estimates: estimates)
            }
        }
    }
    
    func formatCompact(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let h = m / 60
        if h > 0 {
             let remM = m % 60
             return remM > 0 ? "\(h)h \(remM)m" : "\(h)h"
        }
        return "\(m)m"
    }
}

// Subview for Estimate Popover
struct EstimatePopover: View {
    let reminder: EKReminder
    @ObservedObject var estimates: EstimateStore.TaskEstimates
    @EnvironmentObject var estimateStore: EstimateStore
    
    @State private var textInput: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Set Estimate")
                .font(.headline)
            
            TextField("HH:MM", text: Binding(
                get: { textInput },
                set: { newValue in
                    var processed = newValue.filter { "0123456789:".contains($0) }
                    let digits = processed.filter { $0.isNumber }
                    
                    // Auto-colon logic
                    // 1. If typing and hit 2 digits -> append :
                    if !processed.contains(":") && digits.count == 2 && processed.count > textInput.count {
                        processed += ":"
                    }
                    
                    // 2. If 4 digits "0100" -> "01:00"
                    if !processed.contains(":") && digits.count == 4 {
                        let h = String(digits.prefix(2))
                        let m = String(digits.suffix(2))
                        processed = "\(h):\(m)"
                    }
                    
                    textInput = processed
                    parseAndUpdate(processed)
                }
            ))
            .frame(width: 80)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .onAppear {
                // Init local state from store
                let totalSeconds = estimates.estimatedDuration
                if totalSeconds > 0 {
                    let h = Int(totalSeconds) / 3600
                    let m = (Int(totalSeconds) % 3600) / 60
                    textInput = String(format: "%02d:%02d", h, m)
                }
            }
        }
        .padding()
    }
    
    private func parseAndUpdate(_ input: String) {
        // Remove allowed characters to check purely for digits/colon
        let cleaned = input.filter { "0123456789:".contains($0) }
        
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":").map { String($0) }
            if parts.count == 2 {
                let h = Int(parts[0]) ?? 0
                let m = Int(parts[1]) ?? 0
                let seconds = TimeInterval((h * 3600) + (m * 60))
                estimateStore.updateEstimate(for: reminder.calendarItemIdentifier, duration: seconds)
            } else if parts.count == 1 {
                 let h = Int(parts[0]) ?? 0
                 let seconds = TimeInterval(h * 3600)
                 estimateStore.updateEstimate(for: reminder.calendarItemIdentifier, duration: seconds)
            }
        } else {
            // No colon -> check digits
            let digits = cleaned.filter { $0.isNumber }
            if digits.count >= 3 {
                // Formatting for parsing safety anyway, though visual should handle it
                let mStr = String(digits.suffix(2))
                let hStr = String(digits.dropLast(2))
                let h = Int(hStr) ?? 0
                let m = Int(mStr) ?? 0
                let seconds = TimeInterval((h * 3600) + (m * 60))
                estimateStore.updateEstimate(for: reminder.calendarItemIdentifier, duration: seconds)
            } else {
                let m = Int(digits) ?? 0
                let seconds = TimeInterval(m * 60)
                estimateStore.updateEstimate(for: reminder.calendarItemIdentifier, duration: seconds)
            }
        }
    }
}

// Subview for Time Spent Popover
struct TimeSpentPopover: View {
    let reminder: EKReminder
    @ObservedObject var estimates: EstimateStore.TaskEstimates
    @EnvironmentObject var estimateStore: EstimateStore
    
    @State private var textInput: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Set Time Spent")
                .font(.headline)
            
            TextField("HH:MM", text: Binding(
                get: { textInput },
                set: { newValue in
                    var processed = newValue.filter { "0123456789:".contains($0) }
                    let digits = processed.filter { $0.isNumber }
                    
                    // Auto-colon logic
                    // 1. If typing and hit 2 digits -> append :
                    if !processed.contains(":") && digits.count == 2 && processed.count > textInput.count {
                        processed += ":"
                    }
                    
                    // 2. If 4 digits "0100" -> "01:00"
                    if !processed.contains(":") && digits.count == 4 {
                        let h = String(digits.prefix(2))
                        let m = String(digits.suffix(2))
                        processed = "\(h):\(m)"
                    }
                    
                    textInput = processed
                    parseAndUpdate(processed)
                }
            ))
            .frame(width: 80)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .onAppear {
                 let totalSeconds = estimates.timeSpent
                 if totalSeconds > 0 {
                     let h = Int(totalSeconds) / 3600
                     let m = (Int(totalSeconds) % 3600) / 60
                     textInput = String(format: "%02d:%02d", h, m)
                 }
            }
        }
        .padding()
    }
    
    private func parseAndUpdate(_ input: String) {
        let cleaned = input.filter { "0123456789:".contains($0) }
        
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":").map { String($0) }
            if parts.count == 2 {
                let h = Int(parts[0]) ?? 0
                let m = Int(parts[1]) ?? 0
                let seconds = TimeInterval((h * 3600) + (m * 60))
                estimateStore.setTimeSpent(for: reminder.calendarItemIdentifier, seconds: seconds)
            } else if parts.count == 1 {
                 let h = Int(parts[0]) ?? 0
                 let seconds = TimeInterval(h * 3600)
                 estimateStore.setTimeSpent(for: reminder.calendarItemIdentifier, seconds: seconds)
            }
        } else {
            let digits = cleaned.filter { $0.isNumber }
            if digits.count >= 3 {
                // HHMM
                let mStr = String(digits.suffix(2))
                let hStr = String(digits.dropLast(2))
                let h = Int(hStr) ?? 0
                let m = Int(mStr) ?? 0
                let seconds = TimeInterval((h * 3600) + (m * 60))
                estimateStore.setTimeSpent(for: reminder.calendarItemIdentifier, seconds: seconds)
            } else {
                // Minutes
                let m = Int(digits) ?? 0
                let seconds = TimeInterval(m * 60)
                estimateStore.setTimeSpent(for: reminder.calendarItemIdentifier, seconds: seconds)
            }
        }
    }
}

struct TextFieldSpacer: View {
    var body: some View {
        Spacer().frame(width: 12)
    }
}

// MARK: - Performance Optimization
// Cached formatters to avoid expensive initialization during view updates
private struct CachedFormatters {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

