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

    var accentColor: Color {
        switch self {
        case .scan: Color.cyan
        case .plan: Color.blue
        case .compete: Color(red: 1.0, green: 0.82, blue: 0.0)
        case .coach: Color.green
        case .ready: Color.green
        }
    }

    var title: String {
        switch self {
        case .scan: "Body Scan"
        case .plan: "Your Plan"
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
    @State private var cardScale: CGFloat = 0.88
    @State private var cardOpacity: Double = 0

    private let nonReadySteps = TourStep.allCases.filter { $0 != .ready }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                dimLayer

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    cardContainer
                        .padding(.horizontal, 22)
                        .scaleEffect(cardScale)
                        .opacity(cardOpacity)

                    Spacer(minLength: 0)

                    if currentStep != .ready {
                        tabSpotlightBar
                            .padding(.bottom, max(geo.safeAreaInsets.bottom + 4, 16))
                    } else {
                        Spacer().frame(height: max(geo.safeAreaInsets.bottom + 30, 50))
                    }
                }

                if currentStep != .ready {
                    skipButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 20)
                        .padding(.top, geo.safeAreaInsets.top + 14)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.80)) {
                appeared = true
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.80), value: currentStep)
    }

    // MARK: - Dim Layer

    private var dimLayer: some View {
        ZStack {
            Color.black
                .opacity(appeared ? 0.78 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.45), value: appeared)

            Rectangle()
                .fill(.ultraThinMaterial.opacity(appeared ? 0.18 : 0))
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.5), value: appeared)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Card Container

    @ViewBuilder
    private var cardContainer: some View {
        if currentStep == .ready {
            readyCard
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    )
                )
        } else {
            tourCard(for: currentStep)
                .id(currentStep.rawValue)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
        }
    }

    // MARK: - Tour Card

    private func tourCard(for step: TourStep) -> some View {
        VStack(spacing: 0) {
            sheenHighlight(cornerRadius: 28)

            VStack(spacing: 24) {
                iconBadge(for: step)

                VStack(spacing: 9) {
                    Text(step.title)
                        .font(.system(.title2, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(step.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepDots

                Button {
                    hapticImpact(.light)
                    advanceStep()
                } label: {
                    Text("Next")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            Capsule()
                                .fill(.white)
                                .shadow(color: .white.opacity(0.22), radius: 14, y: 5)
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(.top, 6)
            .padding(.bottom, 30)
            .padding(.horizontal, 26)
        }
        .tourCardGlass(cornerRadius: 28)
    }

    // MARK: - Icon Badge

    private func iconBadge(for step: TourStep) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [step.accentColor.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 46
                    )
                )
                .frame(width: 92, height: 92)

            Image(systemName: step.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(step.accentColor)
                .frame(width: 64, height: 64)
                .iconCircleGlass()
                .shadow(color: step.accentColor.opacity(0.25), radius: 12, y: 4)
        }
    }

    // MARK: - Sheen Highlight

    private func sheenHighlight(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                )
            )
            .frame(height: 3)
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 1)
            )
            .padding(.horizontal, 1)
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: 5) {
            ForEach(nonReadySteps, id: \.rawValue) { step in
                let isActive = step == currentStep
                Capsule()
                    .fill(isActive ? Color.white : Color.white.opacity(0.20))
                    .frame(width: isActive ? 24 : 7, height: 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: currentStep)
            }
        }
    }

    // MARK: - Ready Card

    private var readyCard: some View {
        VStack(spacing: 0) {
            sheenHighlight(cornerRadius: 32)

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.32), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 58
                            )
                        )
                        .frame(width: 116, height: 116)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, Color(red: 0.0, green: 0.75, blue: 0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.40), radius: 22, y: 6)
                }

                VStack(spacing: 10) {
                    Text("You're Ready")
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Let's build something elite.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                }

                Button {
                    hapticImpact(.medium)
                    dismiss()
                } label: {
                    Text("Enter Fit AI")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            Capsule()
                                .fill(.white)
                                .shadow(color: .white.opacity(0.20), radius: 18, y: 7)
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(PremiumButtonStyle())
                .padding(.top, 2)
            }
            .padding(.top, 6)
            .padding(.bottom, 34)
            .padding(.horizontal, 26)
        }
        .tourCardGlass(cornerRadius: 32)
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button {
            hapticImpact(.light)
            dismiss()
        } label: {
            Text("Skip Tour")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .skipPillGlass()
        }
        .buttonStyle(PremiumButtonStyle())
    }

    // MARK: - Tab Spotlight Bar

    private var tabSpotlightBar: some View {
        let tabDefs: [(String, String)] = [
            ("camera.viewfinder", "Scan"),
            ("calendar.badge.clock", "Plan"),
            ("trophy.fill", "Compete"),
            ("person.fill", "Profile")
        ]

        return HStack(spacing: 0) {
            ForEach(0..<tabDefs.count, id: \.self) { i in
                let isActive = currentStep.tabIndex == i
                tabItem(
                    icon: tabDefs[i].0,
                    label: tabDefs[i].1,
                    isActive: isActive,
                    accent: isActive ? currentStep.accentColor : .white
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial.opacity(0.20))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 18)
    }

    private func tabItem(icon: String, label: String, isActive: Bool, accent: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.40), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .transition(.scale.combined(with: .opacity))

                    Circle()
                        .fill(.white.opacity(0.10))
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.20), lineWidth: 0.5)
                        }
                        .frame(width: 40, height: 40)
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? accent : .white.opacity(0.18))
                    .scaleEffect(isActive ? 1.12 : 1.0)
            }
            .frame(width: 60, height: 44)

            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white.opacity(0.88) : .white.opacity(0.18))
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isActive)
    }

    // MARK: - Actions

    private func advanceStep() {
        let all = TourStep.allCases
        guard let idx = all.firstIndex(of: currentStep), idx + 1 < all.count else {
            dismiss()
            return
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            currentStep = all[idx + 1]
        }
        if let tabIdx = currentStep.tabIndex {
            selectedTab = tabIdx
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.30)) {
            appeared = false
            cardScale = 0.92
            cardOpacity = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            isShowing = false
            UserDefaults.standard.set(true, forKey: "hasSeenGuidedTour")
        }
    }

    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

// MARK: - Glass Modifiers

private extension View {
    @ViewBuilder
    func tourCardGlass(cornerRadius: CGFloat = 28) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.13), .white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.30), .white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.45), radius: 44, y: 22)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            }
        }
    }

    @ViewBuilder
    func iconCircleGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .circle)
        } else {
            self.background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.20), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.32), .white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
            }
        }
    }

    @ViewBuilder
    func skipPillGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .capsule)
        } else {
            self.background {
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.65))
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.10), .white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                    }
            }
        }
    }
}
