import Foundation

nonisolated enum TourAnchorID: String, CaseIterable, Sendable {
    case tabBar
    case scanReadyCard
    case scanPhotoGuidelines
    case scanAnalyzeButton
    case planSummaryCard
    case planTodayWorkout
    case coachInputField
    case competeBattleCard
    case competeFriends
    case profileUserCard
    case profileSettings
    case profileRestartTour
}

nonisolated struct TourStep: Identifiable, Sendable {
    let id: Int
    let anchorID: TourAnchorID
    let targetTab: Int?
    let title: String
    let body: String
    let isWelcome: Bool
    let isFinal: Bool

    init(id: Int, anchorID: TourAnchorID, targetTab: Int? = nil, title: String, body: String, isWelcome: Bool = false, isFinal: Bool = false) {
        self.id = id
        self.anchorID = anchorID
        self.targetTab = targetTab
        self.title = title
        self.body = body
        self.isWelcome = isWelcome
        self.isFinal = isFinal
    }

    static let allSteps: [TourStep] = [
        TourStep(id: 0, anchorID: .tabBar, targetTab: 0, title: "Welcome 👋", body: "60-second tour. We'll show you the 4 tabs and how to actually use them.", isWelcome: true),
        TourStep(id: 1, anchorID: .tabBar, targetTab: 0, title: "Four tabs, one app", body: "Scan, train, compete, and your profile. Everything you need."),
        TourStep(id: 2, anchorID: .scanReadyCard, targetTab: 0, title: "Scan first 📸", body: "Front + back photos. AI scores your physique and finds weak points."),
        TourStep(id: 3, anchorID: .scanPhotoGuidelines, targetTab: 0, title: "Better photo = better score", body: "Good lighting, neutral pose, plain background. Don't overthink it."),
        TourStep(id: 4, anchorID: .scanAnalyzeButton, targetTab: 0, title: "Analyze 🤖", body: "Get a Fit Score, strengths, weak points, and a 12-week goal projection."),
        TourStep(id: 5, anchorID: .planSummaryCard, targetTab: 1, title: "Your AI plan 💪", body: "Built around your scan, goal, and equipment. Updates as you progress."),
        TourStep(id: 6, anchorID: .planTodayWorkout, targetTab: 1, title: "Or build your own", body: "Switch to Routines for Hevy-style logging. Pick exercises, set rest, save and reuse."),
        TourStep(id: 7, anchorID: .competeBattleCard, targetTab: 2, title: "1v1 battles 🥊", body: "Pick a friend, pick a category (physique, volume, streak), and settle it. Winner takes XP — and bragging rights."),
        TourStep(id: 8, anchorID: .competeFriends, targetTab: 2, title: "Your gym crew 👥", body: "Friends show online presence and head-to-head records. Tap any bubble to see their profile or fire off a challenge."),
        TourStep(id: 9, anchorID: .profileUserCard, targetTab: 3, title: "Your profile 👤", body: "Edit info, track scans, manage Pro, change settings."),
        TourStep(id: 10, anchorID: .profileSettings, targetTab: 3, title: "Customize 🎛️", body: "Units, notifications, Apple Health, language."),
        TourStep(id: 11, anchorID: .profileRestartTour, targetTab: 3, title: "You're set ✅", body: "Start with a scan — everything builds from there. Tap Restart Tour here anytime to replay this.", isFinal: true),
    ]
}
