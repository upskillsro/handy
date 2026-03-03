import SwiftUI

struct ReminderDateEditorField: View {
    let title: String
    let theme: AppTheme
    @Binding var date: Date?

    private var isWhiteTheme: Bool { theme == .white }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)

            if let _ = date {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date ?? Calendar.current.startOfDay(for: Date()) },
                        set: { date = Calendar.current.startOfDay(for: $0) }
                    ),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(minWidth: 120)
                .fixedSize()

                Spacer(minLength: 0)

                Button("Clear") {
                    date = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Button {
                    date = Calendar.current.startOfDay(for: Date())
                } label: {
                    Text("No date")
                        .font(.caption)
                        .foregroundColor(isWhiteTheme ? .primary : .white.opacity(0.86))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(GlassyBackground(theme: theme))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
    }
}

struct ReminderTimeEditorField: View {
    let title: String
    let theme: AppTheme
    let associatedDate: Date?
    @Binding var time: DateComponents?

    private var isEnabled: Bool { associatedDate != nil }
    private var isWhiteTheme: Bool { theme == .white }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)

            if isEnabled, let _ = time {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { displayDate },
                        set: { newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            time = components
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(minWidth: 90)
                .fixedSize()

                Spacer(minLength: 0)

                Button("Clear") {
                    time = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Button {
                    guard isEnabled else { return }
                    time = Calendar.current.dateComponents([.hour, .minute], from: Date())
                } label: {
                    Text(isEnabled ? "No time" : "Date first")
                        .font(.caption)
                        .foregroundColor(isWhiteTheme ? .primary : .white.opacity(0.86))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(GlassyBackground(theme: theme))
                        .opacity(isEnabled ? 1 : 0.6)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)

                Spacer(minLength: 0)
            }
        }
    }

    private var displayDate: Date {
        let baseDate = associatedDate ?? Calendar.current.startOfDay(for: Date())
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = time?.hour ?? Calendar.current.component(.hour, from: Date())
        components.minute = time?.minute ?? Calendar.current.component(.minute, from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }
}

struct ReminderPriorityChips: View {
    let theme: AppTheme
    @Binding var selectedPriority: Int

    var body: some View {
        HStack(spacing: 8) {
            priorityChip(title: "None", priority: 0, foreground: theme == .white ? .primary : .white.opacity(0.88), background: theme == .white ? Color.black.opacity(0.05) : Color.white.opacity(0.08))
            priorityChip(title: "Low", priority: 9, foreground: .blue, background: .blue.opacity(0.16))
            priorityChip(title: "Medium", priority: 5, foreground: .orange, background: .orange.opacity(0.18))
            priorityChip(title: "High", priority: 1, foreground: .red, background: .red.opacity(0.18))
        }
    }

    private func priorityChip(title: String, priority: Int, foreground: Color, background: Color) -> some View {
        let isSelected = selectedPriority == priority
        return Button {
            selectedPriority = priority
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(foreground.opacity(isSelected ? 1 : 0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? background.opacity(1) : background.opacity(0.55))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? foreground.opacity(0.8) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
