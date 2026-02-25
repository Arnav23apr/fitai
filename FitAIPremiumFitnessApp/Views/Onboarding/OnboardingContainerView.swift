import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep: OnboardingStep = .welcome
    @State private var stepHistory: [OnboardingStep] = []

    private let progressSteps: [OnboardingStep] = [
        .welcome,
        .gender,
        .workoutsPerWeek,
        .trainingExperience,
        .trainingLocation,
        .primaryGoal,
        .dateOfBirth,
        .heightWeight,
        .holdingBack,
        .goals,
        .confidence,
        .resultsGraph,
        .enableNotifications,
        .ratingPrompt,
        .referralCode,
        .signUp,
        .paywall,
        .spinWheel,
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: { advance() }, onLogin: { goTo(.signUp) })
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
                            goTo(.spinWheel)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if currentStep != .welcome {
                OnboardingHeaderView(
                    progress: progress,
                    canGoBack: !stepHistory.isEmpty,
                    showsCloseButton: currentStep == .signUp,
                    onBack: { goBack() },
                    onClose: { goTo(.welcome, shouldRecordHistory: false) }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
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
            goTo(.paywall)
        } else {
            goTo(nextStep)
        }
    }

    private var progress: Double {
        guard let index = progressSteps.firstIndex(of: currentStep) else { return 0 }
        return Double(index + 1) / Double(progressSteps.count)
    }

    private func goTo(_ step: OnboardingStep, shouldRecordHistory: Bool = true) {
        if shouldRecordHistory, currentStep != step {
            stepHistory.append(currentStep)
        }
        currentStep = step
    }

    private func goBack() {
        guard let previousStep = stepHistory.popLast() else { return }
        currentStep = previousStep
    }
}

// MARK: - Onboarding Header
struct OnboardingHeaderView: View {
    let progress: Double
    let canGoBack: Bool
    let showsCloseButton: Bool
    let onBack: () -> Void
    let onClose: () -> Void

    @State private var backHapticTrigger: Int = 0
    @State private var closeHapticTrigger: Int = 0

    var body: some View {
        HStack(spacing: 14) {
            LiquidGlassIconButton(systemName: "chevron.left", disabled: !canGoBack) {
                guard canGoBack else { return }
                backHapticTrigger += 1
                onBack()
            }
            .frame(width: 44, height: 44)

            SegmentedOnboardingProgressBar(progress: progress)
                .frame(maxWidth: .infinity)

            Group {
                if showsCloseButton {
                    LiquidGlassIconButton(systemName: "xmark") {
                        closeHapticTrigger += 1
                        onClose()
                    }
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, height: 44)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: backHapticTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: closeHapticTrigger)
    }
}

private struct SegmentedOnboardingProgressBar: View {
    private let segmentCount: Int = 18
    let progress: Double

    private var filledSegments: Int {
        Int((progress * Double(segmentCount)).rounded(.toNearestOrEven))
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < filledSegments ? Color.primary.opacity(0.88) : Color.primary.opacity(0.14))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.22), value: filledSegments)
            }
        }
        .frame(width: 196)
    }
}

private struct LiquidGlassIconButton: View {
    let systemName: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary.opacity(disabled ? 0.4 : 0.95))
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(LiquidPressButtonStyle())
        .disabled(disabled)
        .contentShape(Circle())
    }
}

private struct LiquidPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
