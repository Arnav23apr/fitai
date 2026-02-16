import SwiftUI

@Observable
@MainActor
class AppState {
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var showSplash: Bool = true
    var profile: UserProfile = AppState.loadProfile()

    func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }

    nonisolated private static func loadProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return profile
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        saveProfile()
    }

    func logout() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "userProfile")
        profile = UserProfile()
        showSplash = false
    }

    func logWorkout(dayName: String, exercisesCompleted: Int, totalExercises: Int, durationMinutes: Int, completedExerciseNames: [String]) {
        resetWeekIfNeeded()
        let log = WorkoutLog(
            date: Date(),
            dayName: dayName,
            exercisesCompleted: exercisesCompleted,
            totalExercises: totalExercises,
            durationMinutes: durationMinutes,
            completedExerciseNames: completedExerciseNames
        )
        profile.workoutLogs.append(log)
        profile.totalWorkouts += 1
        profile.points += 100 + (exercisesCompleted * 10)

        let dayLabel = currentDayLabel()
        if !profile.completedDaysThisWeek.contains(dayLabel) {
            profile.completedDaysThisWeek.append(dayLabel)
        }

        updateStreak()
        updateTier()
        saveProfile()
    }

    func isDayCompleted(_ dayLabel: String) -> Bool {
        resetWeekIfNeeded()
        return profile.completedDaysThisWeek.contains(dayLabel)
    }

    var workoutsThisWeek: Int {
        resetWeekIfNeeded()
        return profile.completedDaysThisWeek.count
    }

    var totalWorkoutMinutes: Int {
        profile.workoutLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    private func resetWeekIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = profile.weekStartDate else {
            profile.weekStartDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            return
        }
        if let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
           !calendar.isDate(weekStart, equalTo: currentWeekStart, toGranularity: .weekOfYear) {
            profile.completedDaysThisWeek = []
            profile.weekStartDate = currentWeekStart
        }
    }

    private func currentDayLabel() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let labels = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return labels[weekday - 1]
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sortedDates = profile.workoutLogs.map { calendar.startOfDay(for: $0.date) }
        let uniqueDates = Array(Set(sortedDates)).sorted(by: >)

        var streak = 0
        var checkDate = today
        for date in uniqueDates {
            if date == checkDate {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if date < checkDate {
                break
            }
        }
        profile.currentStreak = max(profile.currentStreak, streak)
    }

    private func updateTier() {
        let pts = profile.points
        if pts >= 10000 {
            profile.tier = "Diamond"
        } else if pts >= 5000 {
            profile.tier = "Platinum"
        } else if pts >= 2000 {
            profile.tier = "Gold"
        } else if pts >= 500 {
            profile.tier = "Silver"
        } else {
            profile.tier = "Bronze"
        }
    }
}
