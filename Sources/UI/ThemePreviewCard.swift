import SwiftUI
import AppKit

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    private var isWhiteTheme: Bool { theme == .white }
    private var linePrimaryColor: Color { isWhiteTheme ? Color.black.opacity(0.25) : Color.white.opacity(0.3) }
    private var lineSecondaryColor: Color { isWhiteTheme ? Color.black.opacity(0.12) : Color.white.opacity(0.1) }
    private var labelColor: Color {
        if isWhiteTheme { return .primary }
        return isSelected ? .white : .secondary
    }
    private var cardFillColor: Color {
        if isWhiteTheme {
            return isSelected ? Color.black.opacity(0.08) : Color.black.opacity(0.03)
        }
        return isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05)
    }
    private var cardStrokeColor: Color {
        if isWhiteTheme {
            return isSelected ? Color.black.opacity(0.25) : Color.black.opacity(0.08)
        }
        return isSelected ? Color.white : .clear
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Visual
                ZStack {
                    previewSurface
                    
                    // Text Lines hint
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(linePrimaryColor)
                            .frame(width: 40, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(lineSecondaryColor)
                            .frame(width: 30, height: 4)
                    }
                }
                .frame(height: 60)
                
                // Label
                Text(themeLabel)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(labelColor)
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
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var previewSurface: some View {
        switch theme {
        case .glass:
            RoundedRectangle(cornerRadius: 6)
                .fill(.thinMaterial)
                .opacity(0.5)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        case .dark:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        case .white:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private var themeLabel: String {
        switch theme {
        case .glass:
            return "Glass"
        case .dark:
            return "Dark Gray"
        case .white:
            return "White"
        }
    }
}
