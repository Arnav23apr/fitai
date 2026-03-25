import SwiftUI

struct TourCoachMarkView: View {
    let step: TourStep
    let stepIndex: Int
    let totalSteps: Int
    let anchorFrame: CGRect
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @State private var appeared: Bool = false

    private var placement: PopupPlacement {
        let screenHeight = UIScreen.main.bounds.height
        let midY = anchorFrame.midY
        if midY > screenHeight * 0.55 {
            return .above
        }
        return .below
    }

    private var anchorGap: CGFloat {
        step.anchorID == .tabBar ? 32 : 14
    }

    private var arrowOffset: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let centerX = anchorFrame.midX
        let popupWidth: CGFloat = min(screenWidth - 40, 340)
        let popupCenterX = max(popupWidth / 2 + 20, min(centerX, screenWidth - popupWidth / 2 - 20))
        return centerX - popupCenterX
    }

    var body: some View {
        let screen = UIScreen.main.bounds
        let popupWidth: CGFloat = min(screen.width - 40, 340)
        let estimatedHalfHeight: CGFloat = 90
        let centerX = anchorFrame.midX
        let popupX = max(popupWidth / 2 + 20, min(centerX, screen.width - popupWidth / 2 - 20))

        let rawY: CGFloat = placement == .below
            ? anchorFrame.maxY + anchorGap + estimatedHalfHeight
            : anchorFrame.minY - anchorGap - estimatedHalfHeight
        let safeMinY: CGFloat = 110 + estimatedHalfHeight
        let safeMaxY: CGFloat = screen.height - 100 - estimatedHalfHeight
        let clampedY = max(safeMinY, min(rawY, safeMaxY))

        VStack(spacing: 0) {
            if placement == .below {
                calloutArrow(pointingUp: true)
                    .offset(x: arrowOffset)
            }

            glassCard(popupWidth: popupWidth)

            if placement == .above {
                calloutArrow(pointingUp: false)
                    .offset(x: arrowOffset)
            }
        }
        .position(
            x: popupX,
            y: clampedY
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                appeared = true
            }
        }
        .onChange(of: stepIndex) { _, _ in
            appeared = false
            withAnimation(.spring(duration: 0.4, bounce: 0.15).delay(0.05)) {
                appeared = true
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stepIndex)
    }

    private func glassCard(popupWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(step.title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(stepIndex + 1) / \(totalSteps)")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(.capsule)
            }

            Text(step.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            progressDots

            HStack(spacing: 10) {
                if stepIndex > 1 {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text(step.isFinal ? "Let's go" : "Next")
                            .font(.subheadline.weight(.semibold))
                        if !step.isFinal {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.capsule)
                }
            }
        }
        .padding(16)
        .frame(width: popupWidth)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.55))
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == stepIndex ? Color.blue : Color.primary.opacity(0.1))
                    .frame(width: i == stepIndex ? 16 : 6, height: 4)
                    .animation(.spring(duration: 0.3), value: stepIndex)
            }
        }
    }

    private func calloutArrow(pointingUp: Bool) -> some View {
        TourTriangle()
            .fill(.ultraThinMaterial)
            .overlay(
                TourTriangle()
                    .fill(Color(.systemBackground).opacity(0.55))
            )
            .frame(width: 16, height: 8)
            .rotationEffect(.degrees(pointingUp ? 0 : 180))
            .shadow(color: .black.opacity(0.06), radius: 2, y: pointingUp ? -1 : 1)
    }
}

private struct TourTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

nonisolated enum PopupPlacement: Sendable {
    case above
    case below
}
