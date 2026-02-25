import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Int = 0
    @State private var appeared: Bool = false
    @State private var showPremiumWelcome: Bool = false
    @State private var showPremiumTour: Bool = false
    @State private var premiumTourStep: PremiumTourStep = .scan
    @State private var premiumHapticTrigger: Int = 0

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab(L.t("scan", lang), systemImage: "camera.viewfinder", value: 0) {
                    ScanView()
                }
                Tab(L.t("plan", lang), systemImage: "calendar.badge.clock", value: 1) {
                    PlanView()
                }
                Tab(L.t("compete", lang), systemImage: "trophy.fill", value: 2) {
                    CompeteView()
                }
                Tab(L.t("profile", lang), systemImage: "person.fill", value: 3) {
                    ProfileView()
                }
            }
            .tint(.primary)
            .opacity(appeared ? 1 : 0)

            if showPremiumWelcome {
                PremiumWelcomeOverlay {
                    appState.dismissPremiumWelcome()
                    showPremiumWelcome = false
                    if appState.shouldShowPremiumTour {
                        showPremiumTour = true
                        premiumTourStep = .scan
                    }
                    premiumHapticTrigger += 1
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if showPremiumTour {
                PremiumTourOverlay(
                    step: premiumTourStep,
                    onNext: { advancePremiumTour() },
                    onSkip: { finishPremiumTour() },
                    onEnter: { finishPremiumTour() },
                    selectedTab: $selectedTab
                )
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: premiumHapticTrigger)
        .animation(.easeInOut(duration: 0.4), value: showPremiumWelcome)
        .animation(.easeInOut(duration: 0.3), value: showPremiumTour)
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }

            if appState.shouldShowPremiumWelcome {
                showPremiumWelcome = true
            } else if appState.shouldShowPremiumTour {
                showPremiumTour = true
            }
        }
    }

    private func advancePremiumTour() {
        premiumHapticTrigger += 1
        if let next = premiumTourStep.next {
            withAnimation(.easeInOut(duration: 0.3)) {
                premiumTourStep = next
            }
        } else {
            finishPremiumTour()
        }
    }

    private func finishPremiumTour() {
        premiumHapticTrigger += 1
        appState.completePremiumTour()
        withAnimation(.easeInOut(duration: 0.3)) {
            showPremiumTour = false
        }
    }
}

private struct PremiumWelcomeOverlay: View {
    @State private var appeared: Bool = false
    @State private var shimmerPhase: CGFloat = -220
    let onStart: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.11, blue: 0.16), Color(red: 0.16, green: 0.09, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.green.opacity(0.18))
                .blur(radius: 80)
                .frame(width: 280, height: 280)
                .offset(x: -110, y: -220)

            Circle()
                .fill(Color.purple.opacity(0.2))
                .blur(radius: 90)
                .frame(width: 260, height: 260)
                .offset(x: 120, y: -260)

            ForEach(0..<14, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: CGFloat((index * 27) % 220) - 110, y: CGFloat((index * 39) % 280) - 170)
                    .blur(radius: 0.3)
                    .opacity(appeared ? 0.7 : 0.1)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(Double(index) * 0.08), value: appeared)
            }

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 86, height: 86)
                            .blur(radius: 0.6)

                        Image("FitAILogoWhite")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                    }

                    VStack(spacing: 10) {
                        Text("Welcome to Fit AI Pro")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text("You’ve unlocked advanced physique analysis, elite tracking, and AI-powered coaching.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Text("Pro Activated")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 1.0, green: 0.90, blue: 0.65))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.35, green: 0.28, blue: 0.12).opacity(0.45))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color(red: 1.0, green: 0.86, blue: 0.58).opacity(0.55), lineWidth: 0.8)
                        )
                        .shadow(color: Color.yellow.opacity(0.24), radius: 14, y: 2)

                    Button(action: onStart) {
                        Text("Start My Journey")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.8)
                                    )
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.35), Color.clear],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: 170)
                                            .offset(x: shimmerPhase)
                                    }
                                    .shadow(color: Color.white.opacity(0.12), radius: 14, y: 8)
                            }
                    }
                    .buttonStyle(PremiumScaleButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 30)
                .background {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 30, y: 12)
                }
                .padding(.horizontal, 22)

                Spacer(minLength: 0)
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.95)
            .offset(y: appeared ? 0 : 26)
        }
        .onAppear {
            withAnimation(.spring(response: 0.68, dampingFraction: 0.82)) {
                appeared = true
            }
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                shimmerPhase = 220
            }
        }
    }
}

private enum PremiumTourStep: Int, CaseIterable {
    case scan
    case plan
    case compete
    case coach
    case share
    case ready

    var next: PremiumTourStep? {
        guard let currentIndex = Self.allCases.firstIndex(of: self), currentIndex + 1 < Self.allCases.count else {
            return nil
        }
        return Self.allCases[currentIndex + 1]
    }

    var title: String {
        switch self {
        case .scan: return "Scan"
        case .plan: return "Plan"
        case .compete: return "Compete"
        case .coach: return "AI Coach"
        case .share: return "Share Cards"
        case .ready: return "You’re Ready."
        }
    }

    var message: String {
        switch self {
        case .scan:
            return "Start with a body scan to get personalized insights and detect strengths & weak points."
        case .plan:
            return "Your workouts are tailored to your physique and goals. Track volume, PRs, and progress."
        case .compete:
            return "Earn points, unlock tiers, challenge friends, and climb the leaderboard."
        case .coach:
            return "Ask anything. Nutrition, recovery, form, strategy — your AI coach adapts to you."
        case .share:
            return "Share your total volume, PRs, and progress with premium share overlays."
        case .ready:
            return "Let’s build something elite."
        }
    }

    var buttonTitle: String {
        self == .ready ? "Enter Fit AI" : "Next"
    }
}

private struct PremiumTourOverlay: View {
    let step: PremiumTourStep
    let onNext: () -> Void
    let onSkip: () -> Void
    let onEnter: () -> Void
    @Binding var selectedTab: Int

    var body: some View {
        GeometryReader { proxy in
            let target = focusRect(in: proxy.size)

            ZStack {
                spotlightLayer(for: target)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(step.title)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(step.message)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button("Skip Tour", action: onSkip)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .buttonStyle(PremiumScaleButtonStyle())

                            Spacer()

                            Button(step.buttonTitle) {
                                if step == .ready {
                                    onEnter()
                                } else {
                                    onNext()
                                }
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.8)
                                    )
                            )
                            .buttonStyle(PremiumScaleButtonStyle())
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 20))
                }
            }
            .onAppear { syncTab() }
            .onChange(of: step) { _, _ in syncTab() }
            .animation(.easeInOut(duration: 0.28), value: step)
        }
    }

    private func syncTab() {
        switch step {
        case .scan, .share:
            selectedTab = 0
        case .plan, .coach:
            selectedTab = 1
        case .compete:
            selectedTab = 2
        case .ready:
            break
        }
    }

    private func spotlightLayer(for rect: CGRect) -> some View {
        ZStack {
            Color.black.opacity(0.72)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .blendMode(.destinationOut)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        .blur(radius: 0.2)
                        .position(x: rect.midX, y: rect.midY)
                )
        }
        .compositingGroup()
    }

    private func focusRect(in size: CGSize) -> CGRect {
        let tabWidth = size.width / 4
        let tabY = size.height - 50

        switch step {
        case .scan:
            return CGRect(x: tabWidth * 0 + 8, y: tabY, width: tabWidth - 16, height: 44)
        case .plan:
            return CGRect(x: tabWidth * 1 + 8, y: tabY, width: tabWidth - 16, height: 44)
        case .compete:
            return CGRect(x: tabWidth * 2 + 8, y: tabY, width: tabWidth - 16, height: 44)
        case .coach:
            return CGRect(x: size.width - 108, y: size.height - 178, width: 78, height: 78)
        case .share:
            return CGRect(x: size.width - 150, y: size.height - 242, width: 122, height: 56)
        case .ready:
            return CGRect(x: (size.width - 220) / 2, y: size.height * 0.28, width: 220, height: 96)
        }
    }
}

private struct PremiumScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
