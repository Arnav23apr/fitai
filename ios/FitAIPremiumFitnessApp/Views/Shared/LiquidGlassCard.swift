import SwiftUI

/// Reusable "Liquid Glass" card surface. Same treatment as the workout
/// hero card in PlanView (`TodayHeroGlass`), generalized so the friend
/// card, activity rows, and any other accent-tinted surface can share
/// one visual language.
///
/// On iOS 26 it uses the real `glassEffect` material with an accent
/// tint; on older OSes it falls back to `.ultraThinMaterial` + a
/// gradient overlay + a tinted stroke. The two paths are visually
/// close enough that callers don't need to think about it.
struct LiquidGlassCard: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat
    /// Bumps the tint + stroke + shadow weight. Use for hero surfaces
    /// like the workout-of-the-day card; default for everything else.
    let isProminent: Bool

    init(tint: Color, cornerRadius: CGFloat = 16, isProminent: Bool = false) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.isProminent = isProminent
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(tint.opacity(isProminent ? 0.20 : 0.12))
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    tint.opacity(isProminent ? 0.40 : 0.22),
                                    tint.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isProminent ? 1.1 : 0.7
                        )
                )
                .shadow(
                    color: tint.opacity(isProminent ? 0.22 : 0.08),
                    radius: isProminent ? 18 : 10,
                    y: isProminent ? 8 : 4
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(isProminent ? 0.16 : 0.10),
                                    tint.opacity(isProminent ? 0.06 : 0.03),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    tint.opacity(isProminent ? 0.30 : 0.18),
                                    tint.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isProminent ? 1.1 : 0.7
                        )
                )
        }
    }
}

extension View {
    /// `.liquidGlassCard(tint: .blue)` — accent-tinted glass surface.
    func liquidGlassCard(
        tint: Color,
        cornerRadius: CGFloat = 16,
        isProminent: Bool = false
    ) -> some View {
        modifier(LiquidGlassCard(tint: tint, cornerRadius: cornerRadius, isProminent: isProminent))
    }
}

/// Pill-shaped Liquid Glass surface for primary CTAs. iOS 26 uses real
/// `.glassEffect()` with the brand tint; older builds fall back to a
/// frosted material + subtle gradient overlay so the button still reads
/// "glassy" without flat regressions.
struct LiquidGlassButton: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.22)).interactive(),
                    in: .capsule
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.35),
                                    tint.opacity(0.25),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: tint.opacity(0.20), radius: 14, y: 4)
        } else {
            content
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.18),
                                    tint.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    tint.opacity(0.20),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: tint.opacity(0.18), radius: 12, y: 4)
        }
    }
}
