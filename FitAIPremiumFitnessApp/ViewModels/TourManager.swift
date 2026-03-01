import SwiftUI

@Observable
@MainActor
class TourManager {
    var isActive: Bool = false
    var currentStepIndex: Int = 0
    var anchorFrames: [TourAnchorID: CGRect] = [:]
    var showWelcome: Bool = false
    var selectedTab: Int = 0
    var isTransitioning: Bool = false

    private let completedKey = "tourCompleted"
    private let skippedKey = "tourSkipped"

    var hasCompletedTour: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    var hasSkippedTour: Bool {
        UserDefaults.standard.bool(forKey: skippedKey)
    }

    var currentStep: TourStep? {
        guard isActive, currentStepIndex < TourStep.allSteps.count else { return nil }
        return TourStep.allSteps[currentStepIndex]
    }

    var totalSteps: Int { TourStep.allSteps.count }

    var currentAnchorFrame: CGRect? {
        guard let step = currentStep else { return nil }
        return anchorFrames[step.anchorID]
    }

    func checkAndShowWelcome() {
        guard !hasCompletedTour && !hasSkippedTour else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                showWelcome = true
            }
        }
    }

    func startTour() {
        withAnimation(.spring(duration: 0.4)) {
            showWelcome = false
            currentStepIndex = 1
            isActive = true
        }
        navigateToStepTab()
    }

    func restartTour() {
        UserDefaults.standard.set(false, forKey: completedKey)
        UserDefaults.standard.set(false, forKey: skippedKey)
        anchorFrames = [:]
        currentStepIndex = 0
        withAnimation(.spring(duration: 0.4)) {
            showWelcome = true
        }
    }

    func dismissWelcome() {
        withAnimation(.spring(duration: 0.35)) {
            showWelcome = false
        }
        UserDefaults.standard.set(true, forKey: skippedKey)
    }

    func next() {
        guard isActive else { return }
        let nextIndex = currentStepIndex + 1
        if nextIndex >= TourStep.allSteps.count {
            completeTour()
            return
        }

        let nextStep = TourStep.allSteps[nextIndex]
        let needsTabSwitch = nextStep.targetTab != TourStep.allSteps[currentStepIndex].targetTab

        if needsTabSwitch {
            isTransitioning = true
            withAnimation(.spring(duration: 0.3)) {
                currentStepIndex = nextIndex
            }
            if let tab = nextStep.targetTab {
                selectedTab = tab
            }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.spring(duration: 0.35)) {
                    isTransitioning = false
                }
            }
        } else {
            withAnimation(.spring(duration: 0.35)) {
                currentStepIndex = nextIndex
            }
        }
    }

    func back() {
        guard isActive, currentStepIndex > 1 else { return }
        let prevIndex = currentStepIndex - 1
        let prevStep = TourStep.allSteps[prevIndex]
        let needsTabSwitch = prevStep.targetTab != TourStep.allSteps[currentStepIndex].targetTab

        if needsTabSwitch {
            isTransitioning = true
            withAnimation(.spring(duration: 0.3)) {
                currentStepIndex = prevIndex
            }
            if let tab = prevStep.targetTab {
                selectedTab = tab
            }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.spring(duration: 0.35)) {
                    isTransitioning = false
                }
            }
        } else {
            withAnimation(.spring(duration: 0.35)) {
                currentStepIndex = prevIndex
            }
        }
    }

    func skipTour() {
        withAnimation(.spring(duration: 0.35)) {
            isActive = false
            showWelcome = false
        }
        UserDefaults.standard.set(true, forKey: skippedKey)
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    func completeTour() {
        withAnimation(.spring(duration: 0.35)) {
            isActive = false
        }
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    func registerAnchor(_ id: TourAnchorID, frame: CGRect) {
        if frame != .zero {
            anchorFrames[id] = frame
        }
    }

    private func navigateToStepTab() {
        guard let step = currentStep, let tab = step.targetTab else { return }
        selectedTab = tab
    }
}
