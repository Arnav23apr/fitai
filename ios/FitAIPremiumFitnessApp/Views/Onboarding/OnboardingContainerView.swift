import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    var startAtLogin: Bool = false
    @State private var currentStep: OnboardingStep = .gender
    @State private var isGoingBack: Bool = false

    // Steps that show progress in the onboarding header. The
    // post-personalization screens (enableNotifications, appleHealth)
    // are deliberately excluded so the bar doesn't imply more steps
    // than the user actually sees.
    private let progressSteps: [OnboardingStep] = [
        .name, .gender, .workoutsPerWeek, .preferredTrainingDays, .trainingExperience, .trainingLocation,
        .primaryGoal, .hardTruth, .trustUs, .dateOfBirth, .heightWeight,
        .holdingBack, .physiqueReward, .goals, .confidence,
        .onePercent, .resultsGraph, .commitment,
        .planPreview, .referralCode, .signUp, .username
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
                case .name:
                    NameView(onContinue: { advance() })
                case .gender:
                    GenderView(onContinue: { advance() })
                case .workoutsPerWeek:
                    WorkoutsPerWeekView(onContinue: { advance() })
                case .preferredTrainingDays:
                    PreferredTrainingDaysView(onContinue: { advance() })
                case .trainingExperience:
                    TrainingExperienceView(onContinue: { advance() })
                case .trainingLocation:
                    TrainingLocationView(onContinue: { advance() })
                case .primaryGoal:
                    PrimaryGoalView(onContinue: { advance() })
                case .hardTruth:
                    HardTruthView(onContinue: { advance() })
                case .dateOfBirth:
                    DateOfBirthView(onContinue: { advance() })
                case .heightWeight:
                    HeightWeightView(onContinue: { advance() })
                case .trustUs:
                    TrustUsView(onContinue: { advance() })
                case .holdingBack:
                    HoldingBackView(onContinue: { advance() })
                case .physiqueReward:
                    PhysiqueRewardView(onContinue: { advance() })
                case .goals:
                    GoalsView(onContinue: { advance() })
                case .confidence:
                    ConfidenceView(onContinue: { advance() })
                case .onePercent:
                    OnePercentView(onContinue: { advance() })
                case .resultsGraph:
                    ResultsGraphView(onContinue: { advance() })
                case .planPreview:
                    PlanPreviewView(onContinue: { advance() })
                case .commitment:
                    CommitmentView(onContinue: { advance() })
                case .referralCode:
                    ReferralCodeView(onContinue: { advance() })
                case .signUp:
                    SignUpView(onContinue: { advance() })
                case .username:
                    UsernamePickerView(
                        title: "Pick your @handle",
                        subtitle: "Friends will use this to find you in 1v1 battles.",
                        isModal: false,
                        onConfirm: { final in
                            appState.profile.username = final
                            await SupabaseSyncService.shared.setIdentity(
                                userId: appState.currentUserIdPublic ?? "",
                                name: appState.profile.name,
                                username: final,
                                email: appState.profile.email
                            )
                            await MainActor.run { advance() }
                        }
                    )
                // .paywall / .welcomePro / .spinWheel were removed from
                // the linear onboarding sequence. FitAI now follows the
                // Umax pattern: paywall fires at the scan-result reveal
                // in the main app instead of during onboarding. The
                // PaywallView / WelcomeProView / SpinWheelView struct
                // files are still imported elsewhere and presented as
                // sheets — they're just no longer onboarding steps.
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

        // After sign-in, if the user has no profile data (new or deleted account),
        // route them through full onboarding starting at gender instead of
        // skipping straight to paywall. Returning users never reach here — their
        // hasCompletedOnboarding is already true and ContentView shows MainTabView.
        if currentStep == .signUp && appState.profile.gender.isEmpty {
            // First data-collection step is now .name (added before .gender).
            currentStep = .name
            return
        }

        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            appState.completeOnboarding()
            return
        }
        var nextStep = allSteps[currentIndex + 1]
        // Skip sign-up step if the user is already logged in (they signed in
        // first, then got routed through data-collection onboarding).
        if nextStep == .signUp && appState.isLoggedIn {
            guard currentIndex + 2 < allSteps.count else {
                appState.completeOnboarding()
                return
            }
            nextStep = allSteps[currentIndex + 2]
        }
        // No more paywall / welcomePro / spinWheel redirects — those
        // steps were pulled out of the onboarding flow. advance()
        // just moves linearly through the remaining onboarding steps.
        currentStep = nextStep
    }

    private func goBack() {
        // From .gender, go back to the splash screen (or stay if already logged in —
        // the user signed in first, so going to splash would be confusing)
        if currentStep == .gender {
            isGoingBack = true
            appState.showSplash = true
            return
        }
        let allSteps = OnboardingStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep), idx > 0 else { return }
        isGoingBack = true
        var prev = allSteps[idx - 1]
        // Skip .signUp when going back if already logged in
        if prev == .signUp && appState.isLoggedIn, idx >= 2 {
            prev = allSteps[idx - 2]
        }
        // Skip .welcome — it's handled by SwipeUpSplashView now
        if prev == .welcome {
            appState.showSplash = true
            return
        }
        currentStep = prev
    }
}
