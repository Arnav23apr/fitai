import SwiftUI
import Auth
import WidgetKit

@Observable
@MainActor
class AppState {
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var showSplash: Bool = true
    var profile: UserProfile = AppState.loadProfile()
    var isAuthenticating: Bool = false
    var authError: String? = nil
    var isLoggedIn: Bool = false
    var scanHistory: [ScanHistoryEntry] = []

    init() {
        scanHistory = ScanHistoryService.shared.loadAll()
        Task { await checkSession() }
    }

    func checkSession() async {
        if let session = await SupabaseAuthService.shared.currentSession() {
            isLoggedIn = true
            if let email = session.user.email, profile.email.isEmpty {
                profile.email = email
            }
        }
    }

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

    func saveScanResult(_ result: ScanResult) {
        profile.latestScore = result.overallScore
        profile.lastScanDate = result.date
        profile.totalScans += 1
        profile.weakPoints = result.weakPoints
        profile.strongPoints = result.strongPoints
        saveProfile()

        let entry = ScanHistoryEntry(from: result)
        ScanHistoryService.shared.save(entry)
        scanHistory = ScanHistoryService.shared.loadAll()
        saveWidgetData(workoutName: profile.workoutLogs.last?.dayName ?? "Today's Workout", exerciseCount: 6)
        WidgetCenter.shared.reloadAllTimelines()

        NotificationService.shared.reconcileAll(profile: profile, scanHistory: scanHistory)
    }

    var emailConfirmationNeeded: Bool = false

    func signInWithEmail(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        emailConfirmationNeeded = false
        do {
            let session = try await SupabaseAuthService.shared.signInWithEmail(email: email, password: password)
            isLoggedIn = true
            if let userEmail = session.user.email {
                profile.email = userEmail
            }
            let meta = session.user.userMetadata
            let fullName = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue
            if let name = fullName, !name.isEmpty {
                profile.name = name
            } else if profile.name.isEmpty {
                profile.name = "Athlete"
            }
            saveProfile()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    func signUpWithEmail(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        emailConfirmationNeeded = false
        do {
            let session = try await SupabaseAuthService.shared.signUpWithEmail(email: email, password: password)
            isLoggedIn = true
            if let userEmail = session.user.email {
                profile.email = userEmail
            }
            if profile.name.isEmpty {
                profile.name = "Athlete"
            }
            saveProfile()
        } catch let error as AuthError where error == .emailConfirmationRequired {
            emailConfirmationNeeded = true
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?, email: String?) async {
        isAuthenticating = true
        authError = nil
        do {
            let session = try await SupabaseAuthService.shared.signInWithApple(idToken: idToken, nonce: nonce)
            isLoggedIn = true
            if let userEmail = email ?? session.user.email {
                profile.email = userEmail
            }
            let meta = session.user.userMetadata
            let supabaseName = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue
            let appleName = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            let resolvedName = supabaseName ?? (appleName.isEmpty ? nil : appleName)
            profile.name = resolvedName ?? "Athlete"
            saveProfile()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    func signInWithGoogle() async {
        isAuthenticating = true
        authError = nil
        do {
            let session = try await SupabaseAuthService.shared.signInWithGoogle()
            isLoggedIn = true
            if let email = session.user.email {
                profile.email = email
            }
            let meta = session.user.userMetadata
            let fullName = meta["full_name"]?.stringValue
                ?? meta["name"]?.stringValue
            if let name = fullName, !name.isEmpty {
                profile.name = name
            } else {
                profile.name = "Athlete"
            }
            saveProfile()
        } catch {
            if (error as NSError).code == 1 {
                // user cancelled
            } else {
                authError = error.localizedDescription
            }
        }
        isAuthenticating = false
    }

    func logout() {
        Task {
            try? await SupabaseAuthService.shared.signOut()
        }
        isLoggedIn = false
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "userProfile")
        UserDefaults.standard.removeObject(forKey: "cachedAIPlan")
        UserDefaults.standard.removeObject(forKey: "cachedMealPlan")
        ScanHistoryService.shared.clear()
        profile = UserProfile()
        scanHistory = []
        showSplash = false
    }

    func saveWidgetData(workoutName: String, exerciseCount: Int) {
        UserDefaults.standard.set(workoutName, forKey: "widget_workoutName")
        UserDefaults.standard.set(exerciseCount, forKey: "widget_exerciseCount")
        UserDefaults.standard.set(profile.currentStreak, forKey: "widget_streak")
        UserDefaults.standard.set(profile.latestScore ?? 0, forKey: "widget_latestScore")
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
        saveWidgetData(workoutName: dayName, exerciseCount: exercisesCompleted)
        WidgetCenter.shared.reloadAllTimelines()
        if !profile.username.isEmpty {
            Task {
                await LeaderboardService.shared.upsertProfile(
                    username: profile.username,
                    displayName: profile.name,
                    points: profile.points,
                    tier: profile.tier,
                    streak: profile.currentStreak,
                    totalWorkouts: profile.totalWorkouts
                )
            }
        }

        NotificationService.shared.cancelTodaysWorkoutReminder()

        if profile.currentStreak > 0 && profile.currentStreak % 7 == 0 {
            NotificationService.shared.sendStreakMilestone(streak: profile.currentStreak)
        }

        NotificationService.shared.reconcileAll(profile: profile, scanHistory: scanHistory)
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
        profile.currentStreak = streak
    }

    func addBonusPoints(_ points: Int) {
        profile.points += points
        updateTier()
        saveProfile()
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
