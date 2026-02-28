import SwiftUI

struct TierBadgeView: View {
    let tier: String
    let points: Int
    let size: CGFloat

    @State private var glowPhase: Bool = false
    @State private var rotationAngle: Double = 0

    private var tierColor: Color {
        switch tier {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }

    private var tierSecondaryColor: Color {
        switch tier {
        case "Silver": return Color(red: 0.6, green: 0.6, blue: 0.65)
        case "Gold": return Color(red: 0.85, green: 0.65, blue: 0.0)
        case "Platinum": return Color(red: 0.4, green: 0.6, blue: 0.85)
        case "Diamond": return Color(red: 0.4, green: 0.7, blue: 1.0)
        default: return Color(red: 0.65, green: 0.35, blue: 0.10)
        }
    }

    private var tierIcon: String {
        switch tier {
        case "Diamond": return "diamond.fill"
        case "Platinum": return "crown.fill"
        case "Gold": return "star.fill"
        case "Silver": return "shield.fill"
        default: return "shield.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tierColor.opacity(glowPhase ? 0.4 : 0.2),
                            tierColor.opacity(glowPhase ? 0.15 : 0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tierColor.opacity(0.3), tierSecondaryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)

                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [tierColor, tierSecondaryColor, tierColor],
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size, height: size)

                Image(systemName: tierIcon)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tierColor, tierSecondaryColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: tierColor.opacity(0.5), radius: 6)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}
