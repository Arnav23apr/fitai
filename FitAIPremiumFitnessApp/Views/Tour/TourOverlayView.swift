import SwiftUI

struct TourOverlayView: View {
    @Environment(TourManager.self) private var tourManager

    var body: some View {
        ZStack {
            if tourManager.showWelcome {
                welcomeCard
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if tourManager.isActive, tourManager.stepReady,
               let step = tourManager.currentStep,
               let frame = tourManager.currentAnchorFrame, frame != .zero {
                spotlightRing(for: frame)
                    .transition(.opacity)

                TourCoachMarkView(
                    step: step,
                    stepIndex: tourManager.currentStepIndex,
                    totalSteps: tourManager.totalSteps,
                    anchorFrame: frame,
                    onNext: { tourManager.next() },
                    onBack: { tourManager.back() },
                    onSkip: { tourManager.skipTour() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if tourManager.isActive {
                skipPill
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .ignoresSafeArea()
        .animation(.spring(duration: 0.4), value: tourManager.currentStepIndex)
        .animation(.spring(duration: 0.35), value: tourManager.stepReady)
        .animation(.spring(duration: 0.35), value: tourManager.isActive)
        .animation(.spring(duration: 0.35), value: tourManager.showWelcome)
    }

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image("FitAILogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Fit AI")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Let's take a 30-second tour so you know exactly where everything is.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: { tourManager.dismissWelcome() }) {
                    Text("Not Now")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(.capsule)
                }

                Button(action: { tourManager.startTour() }) {
                    Text("Start Tour")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.capsule)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.systemBackground).opacity(0.6))
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.15), radius: 24, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .sensoryFeedback(.impact(weight: .light), trigger: tourManager.showWelcome)
    }

    private func spotlightRing(for frame: CGRect) -> some View {
        let isTabBar = tourManager.currentStep?.anchorID == .tabBar
        return AppleIntelligenceGlowBorder(
            frame: frame,
            cornerRadius: isTabBar ? 28 : 14,
            glowSpread: isTabBar ? 16 : 28
        )
    }

    private var skipPill: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { tourManager.skipTour() }) {
                    HStack(spacing: 5) {
                        Text("Skip Tour")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(.capsule)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: tourManager.isActive)
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)
            Spacer()
        }
    }
}
