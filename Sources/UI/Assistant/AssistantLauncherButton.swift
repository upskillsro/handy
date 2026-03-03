import SwiftUI

struct AssistantLauncherButton: View {
    let isOpen: Bool
    let action: () -> Void
    let theme: AppTheme

    private var backgroundColor: Color {
        switch theme {
        case .glass:
            return isOpen ? Color.white.opacity(0.18) : Color.white.opacity(0.08)
        case .dark:
            return isOpen ? Color.white.opacity(0.16) : Color.black.opacity(0.22)
        case .white:
            return isOpen ? Color.blue.opacity(0.16) : Color.black.opacity(0.05)
        }
    }

    private var foregroundColor: Color {
        if theme == .white {
            return isOpen ? Color.blue : Color.black.opacity(0.8)
        }
        return .white.opacity(isOpen ? 1.0 : 0.9)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isOpen ? "xmark.circle.fill" : "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .help(isOpen ? "Close Assistant" : "Open Assistant")
    }
}
