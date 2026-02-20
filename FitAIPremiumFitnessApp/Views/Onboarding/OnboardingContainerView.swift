import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentStep: OnboardingStep = .welcome
    @State private var paywallSkipped: Bool = false
    @State private var isGoingBack: Bool = false
    @State private var stepHistory: [OnboardingStep] = [.welcome]
    @State private var backTapCount: Int = 0

    private var isDark: Bool { colorScheme == .dark }

    private var shouldShowHeader: Bool {
        switch currentStep {
        case .welcome, .paywall, .spinWheel:
            return false
        default:
            return true
        }
    }

    private var headerSteps: [OnboardingStep] {
        OnboardingStep.allCases.filter {
            switch $0 {
            case .welcome, .paywall, .spinWheel: return false
            default: return true
            }
        }
    }

    private var progress: CGFloat {
        guard let index = headerSteps.firstIndex(of: currentStep) else { return 0 }
        guard headerSteps.count > 1 else { return 0 }
        return CGFloat(index) / CGFloat(headerSteps.count - 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: { advance() }, onLogin: {
                        isGoingBack = false
                        stepHistory.append(.signUp)
                        currentStep = .signUp
                    })
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
                case .enableNotifications:
                    EnableNotificationsView(onContinue: { advance() })
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
                            appState.completeOnboarding()
                        },
                        onSkip: {
                            paywallSkipped = true
                            stepHistory.append(.spinWheel)
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
                insertion: .move(edge: isGoingBack ? .leading : .trailing).combined(with: .opacity),
                removal: .move(edge: isGoingBack ? .trailing : .leading).combined(with: .opacity)
            ))

            if shouldShowHeader {
                onboardingHeader
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.4), value: currentStep)
    }

    private var onboardingHeader: some View {
        HStack(spacing: 14) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: backTapCount)

            HStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { segment in
                    GeometryReader { geo in
                        let fill = segmentFill(for: segment)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            Capsule()
                                .fill(Color.primary)
                                .frame(width: max(0, geo.size.width * fill))
                        }
                    }
                    .frame(height: 5)
                }
            }

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func segmentFill(for segment: Int) -> CGFloat {
        let segmentCount: CGFloat = 2
        let segmentSize = 1.0 / segmentCount
        let segmentStart = CGFloat(segment) * segmentSize
        let segmentEnd = segmentStart + segmentSize
        if progress >= segmentEnd { return 1.0 }
        if progress <= segmentStart { return 0.0 }
        return (progress - segmentStart) / segmentSize
    }

    private func goBack() {
        guard stepHistory.count > 1 else { return }
        backTapCount += 1
        isGoingBack = true
        stepHistory.removeLast()
        currentStep = stepHistory.last ?? .welcome
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
        if nextStep == .spinWheel {
            stepHistory.append(.paywall)
            currentStep = .paywall
        } else {
            stepHistory.append(nextStep)
            currentStep = nextStep
        }
    }
}
