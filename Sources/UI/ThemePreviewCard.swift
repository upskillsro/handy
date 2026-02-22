import SwiftUI
import AppKit

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Visual
                ZStack {
                    if theme == .glass {
                        // Glassy Look
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.thinMaterial)
                            .opacity(0.5)
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        // Dark Gray Look
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(height: 60)
                             .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Text Lines hint
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.3)).frame(width: 40, height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.1)).frame(width: 30, height: 4)
                    }
                }
                .frame(height: 60)
                
                // Label
                Text(theme == .glass ? "Glass" : "Dark Gray")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
