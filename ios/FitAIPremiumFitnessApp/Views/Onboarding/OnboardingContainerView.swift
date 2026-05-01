import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    var startAtLogin: Bool = false
    @State private var currentStep: OnboardingStep = .gender
    @State private var paywallSkipped: Bool = false
    @State private var isGoingBack: Bool = false

    // Steps that show progress in the onboarding header.
    // calculatingPlan/paywall/welcomePro/spinWheel/enableNotifications/appleHealth
    // are deliberately excluded — those are post-personalization moments.
    private let progressSteps: [OnboardingStep] = [
        .gender, .workoutsPerWeek, .trainingExperience, .trainingLocation,
        .primaryGoal, .dateOfBirth, .heightWeight, .holdingBack,
        .goals, .confidence, .resultsGraph, .planPreview,
        .ratingPrompt, .referralCode, .signUp
    ]

    private var showsHeader: Bool {
        progressSteps.contains(currentStep)
    }

    private var progressIndex: Int {
        progressSteps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(
                        onContinue: { advance() },
                        onLogin: {
                            isGoingBack = false
                            currentStep = .signUp
                        }
                    )
                case .gender:
                    GenderView(onContinue: { advance() })
                case .workoutsPerWeek:
                    WorkoutsPerWeekView(onContinue: { advance() })
                case .trainingExperience:
                    TrainingExperienceView(onContinue: { advance() })
                case .trainingLocation:
                    TrainingLocationView(onContinue: { advance() })
                case .primaryGoal:
                    PrimaryGoalView(onContinue: { advance() })
                case .dateOfBirth:
                    DateOfBirthView(onContinue: { advance() })
                case .heightWeight:
                    HeightWeightView(onContinue: { advance() })
                case .holdingBack:
                    HoldingBackView(onContinue: { advance() })
                case .goals:
                    GoalsView(onContinue: { advance() })
                case .confidence:
                    ConfidenceView(onContinue: { advance() })
                case .resultsGraph:
                    ResultsGraphView(onContinue: { advance() })
                case .planPreview:
                    PlanPreviewView(onContinue: { advance() })
                case .ratingPrompt:
                    RatingPromptView(onContinue: { advance() })
                case .referralCode:
                    ReferralCodeView(onContinue: { advance() })
                case .signUp:
                    SignUpView(onContinue: { advance() })
                case .paywall:
                    PaywallView(
                        onSubscribe: {
                            appState.profile.isPremium = true
                            isGoingBack = false
                            currentStep = .welcomePro
                        },
                        onSkip: {
                            paywallSkipped = true
                            currentStep = .spinWheel
                        }
                    )
                case .welcomePro:
                    WelcomeProView(onContinue: {
                        isGoingBack = false
                        currentStep = .enableNotifications
                    })
                case .spinWheel:
                    SpinWheelView(onContinue: {
                        isGoingBack = false
                        currentStep = .enableNotifications
                    })
                case .enableNotifications:
                    EnableNotificationsView(onContinue: { advance() })
                case .appleHealth:
                    AppleHealthOnboardingView(onContinue: {
                        appState.completeOnboarding()
                    })
                }
            }
            .transition(.asymmetric(
                insertion: isGoingBack
                    ? .move(edge: .leading).combined(with: .opacity)
                    : .move(edge: .trailing).combined(with: .opacity),
                removal: isGoingBack
                    ? .move(edge: .trailing).combined(with: .opacity)
                    : .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.snappy(duration: 0.35), value: currentStep)
        .onAppear {
            if startAtLogin {
                currentStep = .signUp
            }
        }
        .overlay(alignment: .top) {
            if showsHeader {
                OnboardingHeaderView(
                    progressIndex: progressIndex,
                    totalSteps: progressSteps.count,
                    showCloseButton: false,
                    onBack: { goBack() },
                    onClose: { advance() }
                )
                .transition(.opacity)
            }
        }
    }

    private func advance() {
        isGoingBack = false
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            appState.completeOnboarding()
            return
        }
        let nextStep = allSteps[currentIndex + 1]
        if nextStep == .spinWheel || nextStep == .welcomePro {
            currentStep = .paywall
        } else {
            currentStep = nextStep
        }
    }

    private func goBack() {
        // From .gender, go back to the splash screen
        if currentStep == .gender {
            isGoingBack = true
            appState.showSplash = true
            return
        }
        let allSteps = OnboardingStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep), idx > 0 else { return }
        isGoingBack = true
        let prev = allSteps[idx - 1]
        // Skip .welcome — it's handled by SwipeUpSplashView now
        if prev == .welcome {
            appState.showSplash = true
            return
        }
        currentStep = prev
    }
}
