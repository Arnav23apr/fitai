import Foundation

nonisolated enum TourAnchorID: String, CaseIterable, Sendable {
    case tabBar
    case scanReadyCard
    case scanPhotoGuidelines
    case scanAnalyzeButton
    case planSummaryCard
    case planTodayWorkout
    case coachInputField
    case competeRankBadge
    case competeChallenges
    case competeLeaderboard
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
        TourStep(id: 0, anchorID: .tabBar, targetTab: 0, title: "Welcome to Fit AI", body: "Let's take a 30-second tour so you know exactly where everything is.", isWelcome: true),
        TourStep(id: 1, anchorID: .tabBar, targetTab: 0, title: "Your 4 core tabs", body: "Scan your physique, get a plan, compete with friends, and manage your profile."),
        TourStep(id: 2, anchorID: .scanReadyCard, targetTab: 0, title: "Scan your physique", body: "Upload front and back photos for AI analysis."),
        TourStep(id: 3, anchorID: .scanPhotoGuidelines, targetTab: 0, title: "Get cleaner results", body: "Good lighting and a neutral pose improves accuracy."),
        TourStep(id: 4, anchorID: .scanAnalyzeButton, targetTab: 0, title: "Analyze with AI", body: "Get strengths, weak points, and your Fit Score."),
        TourStep(id: 5, anchorID: .planSummaryCard, targetTab: 1, title: "Your training plan", body: "Workouts tailored to your scan and goals."),
        TourStep(id: 6, anchorID: .planTodayWorkout, targetTab: 1, title: "Track progress", body: "Log sets, total volume, and hit PRs."),
        TourStep(id: 7, anchorID: .competeRankBadge, targetTab: 2, title: "Rank up", body: "Earn XP from workouts, scans, and challenges."),
        TourStep(id: 8, anchorID: .competeChallenges, targetTab: 2, title: "Daily motivation", body: "Complete challenges to earn XP and streaks."),
        TourStep(id: 9, anchorID: .competeLeaderboard, targetTab: 2, title: "Leaderboard", body: "See where you stand this week."),
        TourStep(id: 10, anchorID: .profileUserCard, targetTab: 3, title: "Your profile", body: "Edit your info, track scans, manage Pro, and settings."),
        TourStep(id: 11, anchorID: .profileSettings, targetTab: 3, title: "Customize Fit AI", body: "Units, notifications, Apple Health, and more."),
        TourStep(id: 12, anchorID: .profileRestartTour, targetTab: 3, title: "You're ready.", body: "Start with a scan. Everything else builds from there.", isFinal: true),
    ]
}
