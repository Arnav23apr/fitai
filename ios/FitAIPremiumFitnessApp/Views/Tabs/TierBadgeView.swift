import SwiftUI

struct TierBadgeView: View {
    let tier: String
    let points: Int
    let size: CGFloat

    @State private var glowPhase: Bool = false
    @State private var rotationAngle: Double = 0

    private var rank: PhysiqueRank {
        PhysiqueRank.from(tier: tier)
    }

    private var tierColor: Color { rank.color }
    private var tierSecondaryColor: Color { rank.secondaryColor }
    private var tierIcon: String { rank.icon }

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
