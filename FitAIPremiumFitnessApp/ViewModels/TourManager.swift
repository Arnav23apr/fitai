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
    var stepReady: Bool = false
    var scrollToAnchor: TourAnchorID? = nil

    private let completedKey = "tourCompleted"
    private let skippedKey = "tourSkipped"
    private var waitTask: Task<Void, Never>?

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
        }
        currentStepIndex = 1
        isActive = true
        isTransitioning = true
        navigateToStepTab()
        waitForAnchorThenShow()
    }

    func restartTour() {
        UserDefaults.standard.set(false, forKey: completedKey)
        UserDefaults.standard.set(false, forKey: skippedKey)
        anchorFrames = [:]
        currentStepIndex = 0
        stepReady = false
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

        stepReady = false
        waitTask?.cancel()

        let nextStep = TourStep.allSteps[nextIndex]
        let needsTabSwitch = nextStep.targetTab != TourStep.allSteps[currentStepIndex].targetTab

        currentStepIndex = nextIndex

        if needsTabSwitch {
            isTransitioning = true
            if let tab = nextStep.targetTab {
                selectedTab = tab
            }
        }

        waitForAnchorThenShow()
    }

    func back() {
        guard isActive, currentStepIndex > 1 else { return }
        let prevIndex = currentStepIndex - 1

        stepReady = false
        waitTask?.cancel()

        let prevStep = TourStep.allSteps[prevIndex]
        let needsTabSwitch = prevStep.targetTab != TourStep.allSteps[currentStepIndex].targetTab

        currentStepIndex = prevIndex

        if needsTabSwitch {
            isTransitioning = true
            if let tab = prevStep.targetTab {
                selectedTab = tab
            }
        }

        waitForAnchorThenShow()
    }

    func skipTour() {
        waitTask?.cancel()
        withAnimation(.spring(duration: 0.35)) {
            isActive = false
            showWelcome = false
            stepReady = false
            isTransitioning = false
        }
        UserDefaults.standard.set(true, forKey: skippedKey)
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    func completeTour() {
        waitTask?.cancel()
        withAnimation(.spring(duration: 0.35)) {
            isActive = false
            stepReady = false
            isTransitioning = false
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

    private func waitForAnchorThenShow() {
        waitTask?.cancel()
        waitTask = Task {
            let anchorID = TourStep.allSteps[currentStepIndex].anchorID
            let minDelay: Duration = isTransitioning ? .milliseconds(400) : .milliseconds(150)
            try? await Task.sleep(for: minDelay)
            if Task.isCancelled { return }

            scrollToAnchor = anchorID

            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }

            var attempts = 0
            let maxAttempts = 30
            while anchorFrames[anchorID] == nil || anchorFrames[anchorID] == .zero {
                attempts += 1
                if attempts >= maxAttempts || Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(100))
            }

            if Task.isCancelled { return }

            withAnimation(.spring(duration: 0.35)) {
                isTransitioning = false
                stepReady = true
            }
        }
    }
}
