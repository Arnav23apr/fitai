import SwiftUI
import Auth
import WidgetKit

@Observable
@MainActor
class AppState {
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var showSplash: Bool = true
    /// True until the initial session check + cloud restore completes.
    /// ContentView keeps the splash visible while this is true to avoid
    /// flashing onboarding before the user's profile has been pulled from Supabase.
    var bootstrapping: Bool = true
    /// Logo splash shown on every cold launch (Apple Music style), independent of onboarding state.
    var showLogoSplash: Bool = true
    var profile: UserProfile = AppState.loadProfile()
    var isAuthenticating: Bool = false
    var authError: String? = nil
    var isLoggedIn: Bool = false
    var scanHistory: [ScanHistoryEntry] = []

    /// The Supabase user ID for the current session (used for cloud sync).
    private var currentUserId: String?

    init() {
        scanHistory = ScanHistoryService.shared.loadAll()
        Task { await checkSession() }
    }

    func checkSession() async {
        defer {
            bootstrapping = false
            // Skip splash for returning users who already completed onboarding
            if hasCompletedOnboarding {
                showSplash = false
            }
        }
        guard let session = await SupabaseAuthService.shared.currentSession() else {
            return
        }
        isLoggedIn = true
        currentUserId = session.user.id.uuidString
        if let email = session.user.email, profile.email.isEmpty {
            profile.email = email
        }
        // Pull profile, points, streak, scans, workouts, hasCompletedOnboarding
        // from Supabase so a returning user lands directly in MainTabView with
        // all their state intact. Cap the wait at 5s so a slow/offline server
        // never pins the splash — running restoreFromCloud directly as the group
        // child means cancellation propagates to the URLSession request when the
        // timeout wins the race.
        let userId = session.user.id.uuidString
        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = await self.restoreFromCloud(userId: userId) }
            group.addTask { try? await Task.sleep(for: .seconds(5)) }
            _ = await group.next()
            group.cancelAll()
        }
    }

    // MARK: - Profile persistence

    func saveProfile() {
        // Save photo to filesystem with encryption (excluded from UserDefaults JSON)
        let photoURL = AppState.profilePhotoURL
        if let photoData = profile.customPhotoData {
            try? photoData.write(to: photoURL, options: .completeFileProtection)
        } else if FileManager.default.fileExists(atPath: photoURL.path) {
            try? FileManager.default.removeItem(at: photoURL)
        }
        // Save profile JSON without photo data
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
        // Sync to cloud in background
        syncProfileToCloud()
    }

    nonisolated private static var profilePhotoURL: URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("profile_photo.jpg")
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("profile_photo.jpg")
    }

    nonisolated static var battlePhotoURL: URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("battle_photo.jpg")
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("battle_photo.jpg")
    }

    func saveBattlePhoto(_ imageData: Data) {
        try? imageData.write(to: AppState.battlePhotoURL, options: .completeFileProtection)
    }

    func loadBattlePhoto() -> Data? {
        try? Data(contentsOf: AppState.battlePhotoURL)
    }

    func clearBattlePhoto() {
        try? FileManager.default.removeItem(at: AppState.battlePhotoURL)
    }

    var hasBattlePhoto: Bool {
        FileManager.default.fileExists(atPath: AppState.battlePhotoURL.path)
    }

    nonisolated private static func loadProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              var profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        // Load photo from filesystem
        profile.customPhotoData = try? Data(contentsOf: profilePhotoURL)
        return profile
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        ensureReferralCode()
        // If the user entered someone's code during onboarding, ask the server
        // to attribute it (increment that referrer's friendsReferredCount).
        claimReferralIfNeeded()
        saveProfile()
    }

    /// Generates a unique 6-char outbound referral code for this user if they
    /// don't have one yet. Excludes confusable chars (0/O, 1/I/l).
    func ensureReferralCode() {
        guard profile.referralCode.isEmpty else { return }
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        profile.referralCode = String((0..<6).map { _ in chars.randomElement()! })
    }

    /// Sends the inbound referral code to Supabase to attribute this signup
    /// to the referrer. Fire-and-forget; server enforces idempotency.
    private func claimReferralIfNeeded() {
        let code = profile.referredByCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty, let userId = currentUserId else { return }
        Task.detached {
            await SupabaseSyncService.shared.claimReferral(referredUserId: userId, referrerCode: code)
        }
    }

    // MARK: - Cloud Sync

    /// Check whether a username is free to use. Allows the caller to keep their
    /// own existing username. Returns nil when the check could not be performed
    /// (e.g. offline) — callers should treat that as "couldn't verify".
    func isUsernameAvailable(_ candidate: String) async -> Bool? {
        await SupabaseSyncService.shared.isUsernameAvailable(candidate, excludingUserId: currentUserId)
    }

    /// Push profile to Supabase in background. Fire-and-forget.
    private func syncProfileToCloud() {
        guard let userId = currentUserId else { return }
        let profileCopy = profile
        let onboarding = hasCompletedOnboarding
        Task.detached {
            await SupabaseSyncService.shared.upsertProfile(
                userId: userId,
                profile: profileCopy,
                hasCompletedOnboarding: onboarding
            )
        }
    }

    /// Called after login to restore user data from Supabase.
    /// Returns true if the user is a returning user (has completed onboarding before).
    private func restoreFromCloud(userId: String) async -> Bool {
        guard let remote = await SupabaseSyncService.shared.fetchProfile(userId: userId) else {
            return false
        }

        // Returning user — restore profile
        var restored = remote.toUserProfile()
        // Keep the photo from local if available
        restored.customPhotoData = profile.customPhotoData

        profile = restored

        // Restore onboarding state
        if remote.hasCompletedOnboarding {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        // Save locally
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }

        // Fetch scan history
        let remoteScans = await SupabaseSyncService.shared.fetchScanHistory(userId: userId)
        let restoredScans = remoteScans.compactMap { $0.toScanHistoryEntry() }
        if !restoredScans.isEmpty {
            if let data = try? JSONEncoder().encode(restoredScans) {
                UserDefaults.standard.set(data, forKey: "scanHistory")
            }
            scanHistory = restoredScans
        }

        // Fetch workout logs
        let remoteLogs = await SupabaseSyncService.shared.fetchWorkoutLogs(userId: userId)
        let restoredLogs = remoteLogs.compactMap { $0.toWorkoutLog() }
        if !restoredLogs.isEmpty {
            profile.workoutLogs = restoredLogs
            if let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: "userProfile")
            }
        }

        return remote.hasCompletedOnboarding
    }

    // MARK: - Scans

    func saveScanResult(_ result: ScanResult) {
        // Consume a referral-earned free scan if not premium and the lifetime
        // freebie has already been used. The first-ever scan is free; subsequent
        // free scans come from the referral pool.
        if !profile.isPremium && profile.totalScans > 0 && profile.freeScansEarned > 0 {
            profile.freeScansEarned -= 1
        }
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

        // Sync scan to cloud
        if let userId = currentUserId {
            let entryCopy = entry
            Task.detached {
                await SupabaseSyncService.shared.insertScan(userId: userId, entry: entryCopy)
            }
        }
    }

    // MARK: - Auth

    var emailConfirmationNeeded: Bool = false

    func signInWithEmail(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        emailConfirmationNeeded = false
        do {
            let session = try await SupabaseAuthService.shared.signInWithEmail(email: email, password: password)
            isLoggedIn = true
            currentUserId = session.user.id.uuidString
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
            await restoreFromCloud(userId: session.user.id.uuidString)
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
            currentUserId = session.user.id.uuidString
            if let userEmail = session.user.email {
                profile.email = userEmail
            }
            if profile.name.isEmpty {
                profile.name = "Athlete"
            }
            saveProfile()
            await restoreFromCloud(userId: session.user.id.uuidString)
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
            currentUserId = session.user.id.uuidString
            if let userEmail = email ?? session.user.email {
                profile.email = userEmail
            }
            let meta = session.user.userMetadata
            let supabaseName = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue
            let appleName = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            let resolvedName = supabaseName ?? (appleName.isEmpty ? nil : appleName)
            profile.name = resolvedName ?? "Athlete"
            saveProfile()
            await restoreFromCloud(userId: session.user.id.uuidString)
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
            currentUserId = session.user.id.uuidString
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
            await restoreFromCloud(userId: session.user.id.uuidString)
        } catch {
            if (error as NSError).code == 1 {
                // user cancelled
            } else {
                authError = error.localizedDescription
            }
        }
        isAuthenticating = false
    }

    // MARK: - Logout

    func logout() {
        // Step 1: Transition UI to the splash screen *first*. SwipeUpSplashView
        // doesn't observe `profile` or `scanHistory`, so once ContentView
        // switches to it there are no live SwiftUI observers on the data we're
        // about to reset. This prevents the data race / crash that happened
        // when we cleared `profile` while MainTabView sub-views were still
        // reading from it mid-render.
        showSplash = true

        // Step 2: On the next runloop tick, sign out and clear all local state.
        Task { @MainActor [weak self] in
            try? await SupabaseAuthService.shared.signOut()
            guard let self else { return }
            self.isLoggedIn = false
            self.currentUserId = nil
            self.hasCompletedOnboarding = false
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "userProfile")
            UserDefaults.standard.removeObject(forKey: "cachedAIPlan")
            UserDefaults.standard.removeObject(forKey: "cachedMealPlan")
            ScanHistoryService.shared.clear()
            self.profile = UserProfile()
            self.scanHistory = []
        }
    }

    func deleteAccount() async {
        // Delete user data from Supabase, then clear local state
        if let userId = currentUserId {
            await SupabaseSyncService.shared.deleteProfile(userId: userId)
        }
        try? await SupabaseAuthService.shared.signOut()
        showSplash = true
        isLoggedIn = false
        currentUserId = nil
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "userProfile")
        UserDefaults.standard.removeObject(forKey: "cachedAIPlan")
        UserDefaults.standard.removeObject(forKey: "cachedMealPlan")
        ScanHistoryService.shared.clear()
        profile = UserProfile()
        scanHistory = []
    }

    // MARK: - Widget

    func saveWidgetData(workoutName: String, exerciseCount: Int) {
        UserDefaults.standard.set(workoutName, forKey: "widget_workoutName")
        UserDefaults.standard.set(exerciseCount, forKey: "widget_exerciseCount")
        UserDefaults.standard.set(profile.currentStreak, forKey: "widget_streak")
        UserDefaults.standard.set(profile.latestScore ?? 0, forKey: "widget_latestScore")
    }

    // MARK: - Workouts

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

        // Sync workout log to cloud
        if let userId = currentUserId {
            let logCopy = log
            Task.detached {
                await SupabaseSyncService.shared.insertWorkoutLog(userId: userId, log: logCopy)
            }
        }
    }

    func isDayCompleted(_ dayLabel: String) -> Bool {
        resetWeekIfNeeded()
        return profile.completedDaysThisWeek.contains(dayLabel)
    }

    /// Unwinds today's workout so the user can redo it. Removes today's
    /// WorkoutLog entries (almost always one), removes per-exercise sets
    /// logged today for the supplied exercises, and refunds the points
    /// granted at finish-time.
    func unlogTodaysWorkout(dayLabel: String, exerciseNames: [String]) {
        let calendar = Calendar.current
        let now = Date()

        let toRemove = profile.workoutLogs.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let pointsToRefund = toRemove.reduce(0) { $0 + 100 + ($1.exercisesCompleted * 10) }
        profile.points = max(0, profile.points - pointsToRefund)
        profile.totalWorkouts = max(0, profile.totalWorkouts - toRemove.count)
        profile.workoutLogs.removeAll { log in
            toRemove.contains { $0.id == log.id }
        }
        profile.completedDaysThisWeek.removeAll { $0 == dayLabel }

        // Drop today's per-exercise logs for the named exercises so the
        // restart starts from the previous session's weights.
        let allLogs = ExerciseLogService.shared.loadAll()
        let kept = allLogs.filter { log in
            !(exerciseNames.contains(log.exerciseName) && calendar.isDate(log.date, inSameDayAs: now))
        }
        ExerciseLogService.shared.replaceAll(kept)

        saveProfile()
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
        let index = weekday - 1
        guard index >= 0, index < labels.count else { return "MON" }
        return labels[index]
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
