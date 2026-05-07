import SwiftUI

/// Layered card surface used across the social sheets, friends list, challenge
/// detail, and onboarding cards. Mirrors the pattern used by the Compete tab
/// battle card and the Profile user card so every "card" in the app feels
/// cohesive instead of flat.
///
/// - `secondarySystemGroupedBackground` base
/// - tinted linear gradient overlay (top-leading → bottom-trailing)
/// - tinted hairline stroke
struct GradientCardBackground: ViewModifier {
    let tintColor: Color
    let cornerRadius: CGFloat

    init(tintColor: Color, cornerRadius: CGFloat = 12) {
        self.tintColor = tintColor
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [
                            tintColor.opacity(0.10),
                            tintColor.opacity(0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tintColor.opacity(0.18), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    /// Sugar so callers can write `.gradientCard(tint: .blue, cornerRadius: 12)`.
    func gradientCard(tint: Color, cornerRadius: CGFloat = 12) -> some View {
        modifier(GradientCardBackground(tintColor: tint, cornerRadius: cornerRadius))
    }
}
