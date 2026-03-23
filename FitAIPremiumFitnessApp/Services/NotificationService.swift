import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private let settingsKey = "notificationSettings"

    func loadSettings() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return settings
    }

    func saveSettings(_ settings: NotificationSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    func reconcileAll(profile: UserProfile, scanHistory: [ScanHistoryEntry]) {
        var settings = loadSettings()
        guard !settings.isPaused else {
            removeAllScheduled()
            return
        }

        settings.lastReconcileDate = Date()
        saveSettings(settings)

        removeAllScheduled()

        if settings.trainingRemindersEnabled {
            scheduleWorkoutReminders(settings: settings, profile: profile)
        }
        if settings.missedWorkoutNudgeEnabled {
            scheduleMissedWorkoutNudge(settings: settings, profile: profile)
        }
        if settings.monthlyRescanEnabled {
            scheduleRescanReminder(profile: profile, scanHistory: scanHistory)
        }
        if settings.streakAlertsEnabled {
            scheduleStreakReminder(profile: profile)
        }
        if settings.hydrationReminderEnabled {
            scheduleHydrationReminder(settings: settings)
        }
        if settings.challengeReminderEnabled {
            scheduleChallengeReminder(profile: profile)
        }
    }

    func removeAllScheduled() {
        center.removeAllPendingNotificationRequests()
    }

    func cancelTodaysWorkoutReminder() {
        center.getPendingNotificationRequests { requests in
            let todayIDs = requests
                .filter { $0.identifier.hasPrefix(NotificationCategory.workoutReminder.rawValue) }
                .map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: todayIDs)
        }
    }

    // MARK: - Workout Reminders

    private func scheduleWorkoutReminders(settings: NotificationSettings, profile: UserProfile) {
        let copy = WorkoutReminderCopy.all
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let todayLabel = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][todayWeekday - 1]
        let alreadyWorkedOutToday = profile.completedDaysThisWeek.contains(todayLabel)

        for weekday in settings.workoutDays {
            let isToday = weekday == todayWeekday
            if isToday && alreadyWorkedOutToday { continue }

            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = settings.reminderHour
            dateComponents.minute = settings.reminderMinute

            let selected = copy[weekday % copy.count]
            let content = makeContent(
                title: selected.title,
                body: selected.body,
                category: .workoutReminder
            )

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let id = "\(NotificationCategory.workoutReminder.rawValue)_\(weekday)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Missed Workout Nudge

    private func scheduleMissedWorkoutNudge(settings: NotificationSettings, profile: UserProfile) {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())
        let todayLabel = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][todayWeekday - 1]

        guard settings.workoutDays.contains(todayWeekday),
              !profile.completedDaysThisWeek.contains(todayLabel) else { return }

        let nudgeHour = min(settings.reminderHour + 4, 21)
        var dateComponents = DateComponents()
        dateComponents.hour = nudgeHour
        dateComponents.minute = 0

        let copy = MissedWorkoutCopy.all.randomElement() ?? MissedWorkoutCopy.all[0]
        let content = makeContent(title: copy.title, body: copy.body, category: .missedWorkout)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let id = "\(NotificationCategory.missedWorkout.rawValue)_today"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Rescan Reminder

    private func scheduleRescanReminder(profile: UserProfile, scanHistory: [ScanHistoryEntry]) {
        if scanHistory.isEmpty {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 3600, repeats: false)
            let copy = FirstScanCopy.all.randomElement() ?? FirstScanCopy.all[0]
            let content = makeContent(title: copy.title, body: copy.body, category: .firstScan)
            let request = UNNotificationRequest(identifier: NotificationCategory.firstScan.rawValue, content: content, trigger: trigger)
            center.add(request)
        } else if let lastScanDate = profile.lastScanDate {
            let daysSince = Calendar.current.dateComponents([.day], from: lastScanDate, to: Date()).day ?? 0
            let daysUntilReminder = max(30 - daysSince, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(daysUntilReminder) * 24 * 3600, repeats: false)
            let copy = RescanCopy.all.randomElement() ?? RescanCopy.all[0]
            let content = makeContent(title: copy.title, body: copy.body, category: .monthlyRescan)
            let request = UNNotificationRequest(identifier: NotificationCategory.monthlyRescan.rawValue, content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Streak / Inactivity

    private func scheduleStreakReminder(profile: UserProfile) {
        guard profile.totalWorkouts >= 2 else { return }

        let calendar = Calendar.current
        let lastWorkoutDate = profile.workoutLogs
            .map(\.date)
            .sorted(by: >)
            .first

        guard let lastDate = lastWorkoutDate else { return }
        let daysSince = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0

        guard daysSince >= 2 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 6 * 3600, repeats: false)
        let copy = StreakCopy.all.randomElement() ?? StreakCopy.all[0]
        let content = makeContent(title: copy.title, body: copy.body, category: .streakReminder)
        let request = UNNotificationRequest(identifier: NotificationCategory.streakReminder.rawValue, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Hydration

    private func scheduleHydrationReminder(settings: NotificationSettings) {
        var dateComponents = DateComponents()
        dateComponents.hour = max(settings.reminderHour + 2, 12)
        dateComponents.minute = 30

        let copy = HydrationCopy.all.randomElement() ?? HydrationCopy.all[0]
        let content = makeContent(title: copy.title, body: copy.body, category: .hydration)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationCategory.hydration.rawValue, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Challenge

    private func scheduleChallengeReminder(profile: UserProfile) {
        guard profile.totalWorkouts >= 3 else { return }

        var dateComponents = DateComponents()
        dateComponents.weekday = 4
        dateComponents.hour = 18
        dateComponents.minute = 0

        let copy = ChallengeCopy.all.randomElement() ?? ChallengeCopy.all[0]
        let content = makeContent(title: copy.title, body: copy.body, category: .challengeReminder)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationCategory.challengeReminder.rawValue, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - PR / Milestone (on-demand, not scheduled)

    func sendPRNotification() {
        let settings = loadSettings()
        guard settings.prMilestoneReminderEnabled, !settings.isPaused else { return }

        let copy = PRCopy.all.randomElement() ?? PRCopy.all[0]
        let content = makeContent(title: copy.title, body: copy.body, category: .prMilestone)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let id = "\(NotificationCategory.prMilestone.rawValue)_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    func sendStreakMilestone(streak: Int) {
        let settings = loadSettings()
        guard settings.prMilestoneReminderEnabled, !settings.isPaused else { return }

        let content = makeContent(
            title: "🔥 \(streak)-Day Streak!",
            body: "You just leveled up your consistency. Keep it rolling.",
            category: .prMilestone
        )

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let id = "\(NotificationCategory.prMilestone.rawValue)_streak_\(streak)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Test Notification

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "💪 Fit AI"
        content.body = "Notifications are working. You're all set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Helpers

    private func makeContent(title: String, body: String, category: NotificationCategory) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        content.userInfo = ["tab": category.deepLinkTab, "category": category.rawValue]
        return content
    }
}

// MARK: - Notification Copy

private struct NotifCopy {
    let title: String
    let body: String
}

private enum WorkoutReminderCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "💪 Time to train", body: "Your plan is ready. Let's go."),
        NotifCopy(title: "🏋️ Your workout is waiting", body: "A great session starts with showing up."),
        NotifCopy(title: "⚡ Keep the momentum going", body: "A quick session today makes all the difference."),
        NotifCopy(title: "🔥 Today's your day", body: "Your body is ready. Your plan is set."),
        NotifCopy(title: "💪 Consistency wins", body: "One more session closer to your goals."),
    ]
}

private enum MissedWorkoutCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "👀 Missed today?", body: "No stress. Get back on track tomorrow."),
        NotifCopy(title: "🔥 Your streak is still alive", body: "Don't let it slip. One workout is all it takes."),
        NotifCopy(title: "💪 Reset your momentum", body: "One session is all it takes to get back in rhythm."),
    ]
}

private enum RescanCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "📸 Time for your monthly check-in", body: "See what changed since your last scan."),
        NotifCopy(title: "📈 Ready to see your progress?", body: "Do a new scan and track your gains."),
        NotifCopy(title: "🔍 Your progress update is waiting", body: "A quick scan shows how far you've come."),
    ]
}

private enum FirstScanCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "📸 Get your first scan in", body: "Let Fit AI build a plan around your body."),
        NotifCopy(title: "💪 Start with a scan", body: "Your personalized journey begins with a baseline."),
    ]
}

private enum StreakCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "🔥 Keep the streak alive", body: "You're closer than you think. Show up today."),
        NotifCopy(title: "⚡ Momentum loves consistency", body: "A small session today keeps the streak going."),
        NotifCopy(title: "🏆 Stay in the game", body: "Your progress is real. Don't let it fade."),
    ]
}

private enum HydrationCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "💧 Hydration check", body: "Your muscles need water. Take a sip."),
        NotifCopy(title: "💦 Quick sip", body: "Keep performance up. Stay hydrated."),
        NotifCopy(title: "🧃 Water first", body: "Hydration fuels recovery and performance."),
    ]
}

private enum ChallengeCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "🏆 Your challenge is still live", body: "A workout today could move you up the leaderboard."),
        NotifCopy(title: "⚔️ You're close to ranking up", body: "Push a little harder this week."),
        NotifCopy(title: "📈 Compete update", body: "Check where you stand on the leaderboard."),
    ]
}

private enum PRCopy {
    static let all: [NotifCopy] = [
        NotifCopy(title: "🏆 New PR unlocked", body: "You just hit a personal best. Incredible work."),
        NotifCopy(title: "💪 Big lift, bigger momentum", body: "That PR is proof you're leveling up."),
        NotifCopy(title: "🔥 Personal record crushed", body: "Your hard work is paying off."),
    ]
}
