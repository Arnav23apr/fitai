import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep: OnboardingStep = .welcome
    @State private var paywallSkipped: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: { advance() }, onLogin: { currentStep = .signUp })
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
                case .referralCode:
                    ReferralCodeView(onContinue: { advance() })
                case .signUp:
                    SignUpView(onContinue: { advance() })
                case .enableNotifications:
                    EnableNotificationsView(onContinue: { advance() })
                case .ratingPrompt:
                    RatingPromptView(onContinue: { advance() })
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
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.snappy(duration: 0.4), value: currentStep)
    }

    private func advance() {
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
}
