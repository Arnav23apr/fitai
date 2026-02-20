import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentStep: OnboardingStep = .welcome
    @State private var paywallSkipped: Bool = false
    @State private var navigationDirection: Edge = .trailing

    private var isDark: Bool { colorScheme == .dark }

    private let trackedSteps: [OnboardingStep] = [
        .gender, .workoutsPerWeek, .trainingExperience, .trainingLocation,
        .primaryGoal, .dateOfBirth, .heightWeight, .holdingBack, .goals,
        .confidence, .resultsGraph, .enableNotifications, .ratingPrompt,
        .referralCode, .signUp
    ]

    private var showNavBar: Bool {
        trackedSteps.contains(currentStep)
    }

    private var progress: CGFloat {
        guard let idx = trackedSteps.firstIndex(of: currentStep) else { return 0 }
        return CGFloat(idx + 1) / CGFloat(trackedSteps.count)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: { advanceForward() }, onLogin: { currentStep = .signUp })
                case .gender:
                    GenderView(onContinue: { advanceForward() })
                case .workoutsPerWeek:
                    WorkoutsPerWeekView(onContinue: { advanceForward() })
                case .trainingExperience:
                    TrainingExperienceView(onContinue: { advanceForward() })
                case .trainingLocation:
                    TrainingLocationView(onContinue: { advanceForward() })
                case .primaryGoal:
                    PrimaryGoalView(onContinue: { advanceForward() })
                case .dateOfBirth:
                    DateOfBirthView(onContinue: { advanceForward() })
                case .heightWeight:
                    HeightWeightView(onContinue: { advanceForward() })
                case .holdingBack:
                    HoldingBackView(onContinue: { advanceForward() })
                case .goals:
                    GoalsView(onContinue: { advanceForward() })
                case .confidence:
                    ConfidenceView(onContinue: { advanceForward() })
                case .resultsGraph:
                    ResultsGraphView(onContinue: { advanceForward() })
                case .referralCode:
                    ReferralCodeView(onContinue: { advanceForward() })
                case .signUp:
                    SignUpView(onContinue: { advanceForward() })
                case .enableNotifications:
                    EnableNotificationsView(onContinue: { advanceForward() })
                case .ratingPrompt:
                    RatingPromptView(onContinue: { advanceForward() })
                case .paywall:
                    PaywallView(
                        onSubscribe: {
                            appState.profile.isPremium = true
                            appState.completeOnboarding()
                        },
                        onSkip: {
                            paywallSkipped = true
                            currentStep = .spinWheel
                        }
                    )
                case .spinWheel:
                    SpinWheelView(onContinue: {
                        appState.completeOnboarding()
                    })
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: navigationDirection).combined(with: .opacity),
                removal: .move(edge: navigationDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
            ))

            if showNavBar {
                VStack {
                    onboardingNavBar
                    Spacer()
                }
            }
        }
        .animation(.snappy(duration: 0.4), value: currentStep)
    }

    private var onboardingNavBar: some View {
        HStack(spacing: 14) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.8) : .black.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: currentStep)

            OnboardingProgressBar(progress: progress, isDark: isDark)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func advanceForward() {
        navigationDirection = .trailing
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            appState.completeOnboarding()
            return
        }
        let nextStep = allSteps[currentIndex + 1]
        if nextStep == .spinWheel {
            currentStep = .paywall
        } else {
            currentStep = nextStep
        }
    }

    private func goBack() {
        navigationDirection = .leading
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        let previousStep = allSteps[currentIndex - 1]
        currentStep = previousStep
    }
}

struct OnboardingProgressBar: View {
    let progress: CGFloat
    let isDark: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                Capsule()
                    .fill(isDark ? Color.white : Color.black)
                    .frame(width: max(geo.size.height, geo.size.width * progress))
                    .animation(.spring(duration: 0.5, bounce: 0.15), value: progress)
            }
        }
        .frame(height: 5)
    }
}
