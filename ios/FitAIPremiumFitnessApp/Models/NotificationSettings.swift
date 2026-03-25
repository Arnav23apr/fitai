import Foundation

nonisolated struct NotificationSettings: Codable, Sendable {
    var trainingRemindersEnabled: Bool = true
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var workoutDays: Set<Int> = [2, 3, 4, 5, 6]
    var missedWorkoutNudgeEnabled: Bool = true
    var monthlyRescanEnabled: Bool = true
    var streakAlertsEnabled: Bool = true
    var hydrationReminderEnabled: Bool = false
    var challengeReminderEnabled: Bool = true
    var prMilestoneReminderEnabled: Bool = true
    var pausedUntil: Date? = nil
    var lastReconcileDate: Date? = nil

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return Date() < pausedUntil
    }

    static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let daySymbols = ["S", "M", "T", "W", "T", "F", "S"]
}

nonisolated enum NotificationCategory: String, Sendable {
    case workoutReminder = "WORKOUT_REMINDER"
    case missedWorkout = "MISSED_WORKOUT"
    case monthlyRescan = "MONTHLY_RESCAN"
    case firstScan = "FIRST_SCAN"
    case streakReminder = "STREAK_REMINDER"
    case hydration = "HYDRATION"
    case challengeReminder = "CHALLENGE_REMINDER"
    case prMilestone = "PR_MILESTONE"

    var deepLinkTab: Int {
        switch self {
        case .workoutReminder, .missedWorkout, .streakReminder: return 1
        case .monthlyRescan, .firstScan: return 0
        case .challengeReminder, .prMilestone: return 2
        case .hydration: return 1
        }
    }
}
