import SwiftUI

struct AssistantPanel: View {
    @ObservedObject var coordinator: AssistantCoordinator
    let theme: AppTheme
    let onClose: () -> Void
    let availableHeight: CGFloat

    @State private var measuredPromptHeight: CGFloat = 44

    private let placeholderText = "Add tasks for today, reschedule something, or paste a transcript from Handy..."

    private var panelFillColor: Color {
        switch theme {
        case .glass:
            return Color.black.opacity(0.18)
        case .dark:
            return Color.black.opacity(0.35)
        case .white:
            return Color.white.opacity(0.98)
        }
    }

    private var borderColor: Color {
        theme == .white ? Color.black.opacity(0.1) : Color.white.opacity(0.08)
    }

    private var helperTextColor: Color {
        theme == .white ? Color.black.opacity(0.6) : Color.white.opacity(0.7)
    }

    private var editorInsetColor: Color {
        switch theme {
        case .glass:
            return Color.black.opacity(0.26)
        case .dark:
            return Color.black.opacity(0.3)
        case .white:
            return Color.black.opacity(0.04)
        }
    }

    private var reviewActionCount: Int {
        groupedReviewActions.reduce(0) { $0 + $1.actions.count }
    }

    private var promptEditorHeight: CGFloat {
        min(max(measuredPromptHeight, 42), 120)
    }

    private var reviewListHeight: CGFloat {
        guard reviewActionCount > 0 else { return 0 }
        let estimated = CGFloat(reviewActionCount) * 58 + CGFloat(max(groupedReviewActions.count - 1, 0)) * 20
        let baseHeight = compactPanelHeight
        let maxReviewHeight = max((availableHeight * (2.0 / 3.0)) - baseHeight, 96)
        return min(max(estimated, 96), maxReviewHeight)
    }

    private var compactPanelHeight: CGFloat {
        max(availableHeight * 0.25, 180)
    }

    private var expandedPanelHeight: CGFloat {
        min(compactPanelHeight + reviewListHeight + 42, availableHeight * (2.0 / 3.0))
    }

    private var panelHeight: CGFloat {
        reviewActionCount > 0 ? expandedPanelHeight : compactPanelHeight
    }

    private var groupedReviewActions: [(kind: AssistantActionKind, actions: [AssistantActionDraft])] {
        guard case .review(let batch) = coordinator.state else { return [] }
        let orderedKinds = AssistantActionKind.allCases.filter { kind in
            batch.actions.contains(where: { $0.kind == kind })
        }
        return orderedKinds.map { kind in
            (kind, batch.actions.filter { $0.kind == kind })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            inputArea
            stateArea
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(panelFillColor)

                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .opacity(theme == .white ? 0.45 : 0.9)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: theme == .white ? Color.black.opacity(0.08) : Color.black.opacity(0.28), radius: 20, x: 0, y: 8)
        .frame(height: panelHeight, alignment: .bottom)
        .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Assistant")
                    .font(.headline)
                Spacer()
                if coordinator.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme == .white ? Color.black.opacity(0.55) : Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }

            Text("Describe what you want to add or change, then review the actions before applying.")
                .font(.caption)
                .foregroundColor(helperTextColor)
        }
    }

    @ViewBuilder
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(editorInsetColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(theme == .white ? Color.black.opacity(0.08) : Color.white.opacity(0.05), lineWidth: 1)
                    )

                AssistantPromptEditor(text: $coordinator.inputText, contentHeight: $measuredPromptHeight, theme: theme)
                    .frame(height: promptEditorHeight)
                    .disabled(coordinator.isBusy)

                if coordinator.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 13))
                        .foregroundColor(helperTextColor.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: promptEditorHeight)

            HStack {
                Text("Type directly here or paste a transcript from Handy.")
                    .font(.caption2)
                    .foregroundColor(helperTextColor)

                Spacer()

                Button("Generate") {
                    coordinator.submitTypedInput()
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isBusy)
            }

        }
    }

    @ViewBuilder
    private var stateArea: some View {
        switch coordinator.state {
        case .idle:
            EmptyView()
        case .recording:
            Label("Voice input is currently disabled in Helpy.", systemImage: "mic.slash")
                .font(.caption)
                .foregroundColor(helperTextColor)
        case .transcribing:
            Label("Voice input is currently disabled in Helpy.", systemImage: "mic.slash")
                .font(.caption)
                .foregroundColor(helperTextColor)
        case .generating:
            Label("Generating reminder actions with Ollama…", systemImage: "sparkles")
                .font(.caption)
                .foregroundColor(helperTextColor)
        case .error(let error):
            VStack(alignment: .leading, spacing: 8) {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                HStack {
                    Button("Try Again") {
                        coordinator.retryLastInput()
                    }
                    .buttonStyle(.bordered)
                    Button("Dismiss") {
                        coordinator.state = .idle
                    }
                    .buttonStyle(.borderless)
                }
            }
        case .review(let batch):
            VStack(alignment: .leading, spacing: 10) {
                Text("Review \(batch.actions.count) action\(batch.actions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if reviewListHeight > 0 {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(groupedReviewActions, id: \.kind) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(sectionTitle(for: section.kind, count: section.actions.count))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(helperTextColor)

                                    ForEach(section.actions) { action in
                                        AssistantDraftCard(
                                            action: action,
                                            onChange: { coordinator.updateAction($0) },
                                            onApply: { coordinator.applyAction($0) },
                                            onDiscard: { coordinator.discardAction(action) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(height: reviewListHeight)
                }

                HStack {
                    Button("Discard All") {
                        coordinator.discardAllActions()
                    }
                    .buttonStyle(.borderless)

                    Button("Try Again") {
                        coordinator.retryLastInput()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Apply All") {
                        coordinator.applyAllActions()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func sectionTitle(for kind: AssistantActionKind, count: Int) -> String {
        let base: String
        switch kind {
        case .create: base = "Creates"
        case .update: base = "Updates"
        case .delete: base = "Deletes"
        case .complete: base = "Status Changes"
        case .reorder: base = "Reordering"
        }
        return "\(base) · \(count)"
    }
}
