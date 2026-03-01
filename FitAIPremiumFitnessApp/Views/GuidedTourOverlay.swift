import SwiftUI

nonisolated enum TourStep: Int, CaseIterable, Sendable {
    case scan
    case plan
    case compete
    case coach
    case ready

    var tabIndex: Int? {
        switch self {
        case .scan: 0
        case .plan: 1
        case .compete: 2
        case .coach: nil
        case .ready: nil
        }
    }

    var icon: String {
        switch self {
        case .scan: "camera.viewfinder"
        case .plan: "calendar.badge.clock"
        case .compete: "trophy.fill"
        case .coach: "brain.head.profile.fill"
        case .ready: "checkmark.seal.fill"
        }
    }

    var title: String {
        switch self {
        case .scan: "Scan"
        case .plan: "Plan"
        case .compete: "Compete"
        case .coach: "AI Coach"
        case .ready: "You're Ready"
        }
    }

    var message: String {
        switch self {
        case .scan:
            "Start with a body scan to get personalized insights and detect strengths & weak points."
        case .plan:
            "Your workouts are tailored to your physique and goals. Track volume, PRs, and progress."
        case .compete:
            "Earn points, unlock tiers, challenge friends, and climb the leaderboard."
        case .coach:
            "Ask anything. Nutrition, recovery, form, strategy — your AI coach adapts to you."
        case .ready:
            "Let's build something elite."
        }
    }
}

struct GuidedTourOverlay: View {
    @Binding var isShowing: Bool
    @Binding var selectedTab: Int
    @State private var currentStep: TourStep = .scan
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.7 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            if currentStep == .ready {
                readyCard
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                tooltipView
                    .transition(.opacity)
            }

            VStack {
                HStack {
                    Spacer()
                    if currentStep != .ready {
                        Button {
                            hapticLight()
                            dismiss()
                        } label: {
                            Text("Skip Tour")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial.opacity(0.4))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .animation(.smooth(duration: 0.35), value: currentStep)
    }

    private var tooltipView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 35
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: currentStep.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.6))
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                        }
                }

                VStack(spacing: 8) {
                    Text(currentStep.title)
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundStyle(.white)

                    Text(currentStep.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepIndicator

                Button {
                    hapticLight()
                    advanceStep()
                } label: {
                    Text("Next")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 160, height: 44)
                        .background {
                            Capsule().fill(.white)
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .padding(.horizontal, 32)

            Spacer()

            tabHighlight
                .padding(.bottom, 8)
        }
    }

    private var stepIndicator: some View {
        let steps = TourStep.allCases.filter { $0 != .ready }
        return HStack(spacing: 6) {
            ForEach(steps, id: \.rawValue) { step in
                Capsule()
                    .fill(step == currentStep ? Color.white : Color.white.opacity(0.2))
                    .frame(width: step == currentStep ? 20 : 8, height: 4)
            }
        }
    }

    private var tabHighlight: some View {
        let tabNames: [(String, String)] = [
            ("camera.viewfinder", "Scan"),
            ("calendar.badge.clock", "Plan"),
            ("trophy.fill", "Compete"),
            ("person.fill", "Profile")
        ]

        return HStack(spacing: 0) {
            ForEach(0..<tabNames.count, id: \.self) { index in
                let isHighlighted = currentStep.tabIndex == index
                VStack(spacing: 4) {
                    Image(systemName: tabNames[index].0)
                        .font(.system(size: 20))
                    Text(tabNames[index].1)
                        .font(.system(size: 10))
                }
                .foregroundStyle(isHighlighted ? .white : .white.opacity(0.25))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.1))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            }
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.3))
        }
        .padding(.horizontal, 16)
    }

    private var readyCard: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .green.opacity(0.3), radius: 16, y: 4)
            }

            VStack(spacing: 10) {
                Text("You're Ready")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)

                Text("Let's build something elite.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Button {
                hapticLight()
                dismiss()
            } label: {
                Text("Enter Fit AI")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        Capsule().fill(.white)
                            .shadow(color: .white.opacity(0.15), radius: 16, y: 6)
                    }
                    .clipShape(Capsule())
            }
            .buttonStyle(PremiumButtonStyle())
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 28)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .padding(.horizontal, 32)
    }

    private func advanceStep() {
        let allSteps = TourStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep),
              idx + 1 < allSteps.count else {
            dismiss()
            return
        }
        currentStep = allSteps[idx + 1]
        if let tabIdx = currentStep.tabIndex {
            selectedTab = tabIdx
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            appeared = false
        }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            isShowing = false
            UserDefaults.standard.set(true, forKey: "hasSeenGuidedTour")
        }
    }

    private func hapticLight() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
}
