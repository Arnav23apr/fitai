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
    /// Mirrors to the local-first services so they know which user to push
    /// updates to. nil while signed-out — those services then operate
    /// local-only until auth completes.
    private var currentUserId: String? {
        didSet {
            BodyMeasurementService.shared.currentUserId = currentUserId
            RoutineService.shared.currentUserId = currentUserId
            CustomExerciseService.shared.currentUserId = currentUserId
        }
    }

    /// Read-only accessor for the current Supabase user id, for view models that
    /// need to filter their own server queries (FriendViewModel, etc.).
    var currentUserIdPublic: String? { currentUserId }

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
        currentUserId = session.user.id.uuidString.lowercased()
        if let email = session.user.email, profile.email.isEmpty {
            profile.email = email
        }
        // Pull profile, points, streak, scans, workouts, hasCompletedOnboarding
        // from Supabase so a returning user lands directly in MainTabView with
        // all their state intact. Cap the wait at 5s so a slow/offline server
        // never pins the splash — running restoreFromCloud directly as the group
        // child means cancellation propagates to the URLSession request when the
        // timeout wins the race.
        let userId = session.user.id.uuidString.lowercased()
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

    /// Update the user's custom avatar image. Handles local persistence
    /// (filesystem + UserDefaults) AND the cloud round-trip (upload to
    /// Supabase Storage `profile_photos` bucket, store URL on profile so
    /// other devices can fetch it via `restoreFromCloud`).
    ///
    /// Pass nil to clear the photo (reverts to SF Symbol avatar) — clears
    /// both the local file and the remote URL.
    func setCustomPhotoData(_ data: Data?) {
        profile.customPhotoData = data

        guard let data, let image = UIImage(data: data),
              let userId = currentUserId else {
            // Clearing photo OR offline — wipe local URL too so we don't
            // keep showing a stale URL pointing at the old photo.
            profile.profilePhotoURL = nil
            saveProfile()
            return
        }

        // Save locally first so the UI updates immediately.
        saveProfile()

        // Upload to bucket; on success, persist the URL and resync the
        // profile so other devices pick it up.
        Task.detached { [weak self] in
            guard let url = await PhotoUploadService.shared
                .uploadProfilePhoto(image: image, userId: userId) else {
                return
            }
            await MainActor.run {
                guard let self else { return }
                self.profile.profilePhotoURL = url
                self.saveProfile()
            }
        }
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
        // Clear the deleted mark so future logins restore normally
        if let userId = currentUserId {
            clearDeletedMark(userId: userId)
        }
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
    /// Last time we pushed `last_seen_at` to the server. Used to debounce
    /// heartbeat writes — bumping on every foreground would write 4-5×
    /// per second of jitter when iOS rapidly toggles foreground/inactive.
    private var lastPresenceBumpAt: Date? = nil

    /// Push `last_seen_at = now()` for the current user, debounced to one
    /// write per minute. Called on app foreground + after sign-in so
    /// friends see this user as "online" within their 5-min presence
    /// window. Best-effort; no UI surface on failure.
    func bumpPresence() async {
        guard let userId = currentUserId else { return }
        if let last = lastPresenceBumpAt,
           Date().timeIntervalSince(last) < 60 {
            return
        }
        lastPresenceBumpAt = Date()
        await SupabaseSyncService.shared.bumpLastSeen(userId: userId)
    }

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

    /// Decode the remote `notification_prefs` jsonb blob into a local
    /// `NotificationSettings`, persist via NotificationService, and
    /// reschedule the actual UNUserNotificationCenter requests. Called
    /// from `restoreFromCloud` so reminder times follow the user.
    private func applyRemoteNotificationPrefs(_ prefs: [String: JSONCodable]) {
        var s = NotificationService.shared.loadSettings()
        if let v = prefs["trainingRemindersEnabled"]?.value as? Bool { s.trainingRemindersEnabled = v }
        if let v = prefs["reminderHour"]?.value as? Int               { s.reminderHour = v }
        if let v = prefs["reminderMinute"]?.value as? Int             { s.reminderMinute = v }
        if let v = prefs["workoutDays"]?.value as? [Any]              { s.workoutDays = Set(v.compactMap { $0 as? Int }) }
        if let v = prefs["missedWorkoutNudgeEnabled"]?.value as? Bool { s.missedWorkoutNudgeEnabled = v }
        if let v = prefs["monthlyRescanEnabled"]?.value as? Bool      { s.monthlyRescanEnabled = v }
        if let v = prefs["streakAlertsEnabled"]?.value as? Bool       { s.streakAlertsEnabled = v }
        if let v = prefs["hydrationReminderEnabled"]?.value as? Bool  { s.hydrationReminderEnabled = v }
        if let v = prefs["challengeReminderEnabled"]?.value as? Bool  { s.challengeReminderEnabled = v }
        if let v = prefs["prMilestoneReminderEnabled"]?.value as? Bool { s.prMilestoneReminderEnabled = v }
        NotificationService.shared.saveSettings(s)
        NotificationService.shared.reconcileAll(profile: profile, scanHistory: scanHistory)
    }

    /// Called after login to restore user data from Supabase.
    /// Returns true if the user is a returning user (has completed onboarding
    /// before). Returns false ONLY for genuinely-new users (no remote row);
    /// transient fetch failures preserve the local profile rather than
    /// resetting the user — this is the Bug A fix where Apple sign-in
    /// would "reset" the account on every login because a single failed
    /// fetch was treated identically to a brand-new signup.
    @discardableResult
    private func restoreFromCloud(userId: String) async -> Bool {
        // If this user previously deleted their account on this device,
        // refuse to restore — treat them as a new user regardless of
        // whether Supabase still has their data (DELETE may have failed)
        if isAccountDeleted(userId: userId) {
            return false
        }

        let status = await SupabaseSyncService.shared.fetchProfileWithStatus(userId: userId)
        let remote: RemoteUserProfile
        switch status {
        case .found(let p):
            remote = p
        case .notFound:
            // Genuinely new user — let onboarding flow take over.
            return false
        case .failed(let reason):
            // Transient fetch failure — DO NOT reset to "new user" state.
            // Preserve any local profile/onboarding state and let the user
            // continue. Next sync attempt (saveProfile, scan, workout) will
            // surface the real error if it's persistent.
            #if DEBUG
            print("[AppState] restoreFromCloud failed (\(reason)) — preserving local state")
            #endif
            // If we have a local profile that already completed onboarding,
            // treat as returning so we don't drop the user back into
            // onboarding.
            return hasCompletedOnboarding
        }

        // Returning user — restore profile
        var restored = remote.toUserProfile()
        // Keep the photo from local if available; otherwise fetch from the
        // remote URL so a fresh device gets the user's avatar back.
        restored.customPhotoData = profile.customPhotoData

        profile = restored

        // Avatar hydration: if we have a remote URL but no local image
        // bytes (fresh sign-in on a new device), download the avatar so
        // the UI can render it locally and so subsequent saves don't
        // accidentally clear `customPhotoData`.
        if profile.customPhotoData == nil,
           let urlString = remote.profilePhotoURL,
           let url = URL(string: urlString),
           let (data, response) = try? await URLSession.shared.data(from: url),
           let http = response as? HTTPURLResponse, http.statusCode == 200 {
            profile.customPhotoData = data
            try? data.write(to: AppState.profilePhotoURL, options: .completeFileProtection)
        }

        // Notification prefs hydration: if remote has a `notification_prefs`
        // jsonb blob, decode it and apply locally so reminder times follow
        // the user across devices.
        if let prefs = remote.notificationPrefs {
            applyRemoteNotificationPrefs(prefs)
        }

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

        // Fetch per-set exercise logs (Bug B fix — these used to live only
        // in UserDefaults and disappeared on logout. Now they round-trip
        // through Supabase so workout history retains sets/volume.)
        let remoteExerciseLogs = await SupabaseSyncService.shared.fetchExerciseLogs(userId: userId)
        let restoredExerciseLogs = remoteExerciseLogs.compactMap { $0.toExerciseLog() }
        if !restoredExerciseLogs.isEmpty {
            ExerciseLogService.shared.replaceAll(restoredExerciseLogs)
        }

        // Fetch body measurements
        let remoteMeasurements = await SupabaseSyncService.shared.fetchBodyMeasurements(userId: userId)
        let restoredMeasurements = remoteMeasurements.compactMap { $0.toBodyMeasurement() }
        if !restoredMeasurements.isEmpty {
            await MainActor.run {
                BodyMeasurementService.shared.replaceAll(restoredMeasurements)
            }
        }

        // Fetch custom routines
        let remoteRoutines = await SupabaseSyncService.shared.fetchRoutines(userId: userId)
        if !remoteRoutines.isEmpty {
            await MainActor.run {
                RoutineService.shared.replaceAll(remoteRoutines)
            }
        }

        // Fetch user-defined custom exercises
        let remoteCustomExercises = await SupabaseSyncService.shared.fetchCustomExercises(userId: userId)
        if !remoteCustomExercises.isEmpty {
            await MainActor.run {
                CustomExerciseService.shared.replaceAll(remoteCustomExercises)
            }
        }

        // Mark this user as online so friends' presence dots light up
        // immediately on the next refresh.
        await bumpPresence()

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
        updateTier()
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

        // Generate / refresh the "Future you" goal projection. Edge function
        // enforces a 90-day cooldown server-side, so calling on every scan
        // is a no-op when one's already current. Front photo is the source.
        if let userId = currentUserIdPublic, let frontPhoto = result.frontPhoto {
            Task.detached { [weak self] in
                guard let sourceURL = await PhotoUploadService.shared
                    .uploadGoalProjectionSource(image: frontPhoto, userId: userId) else {
                    return
                }
                let outcome = await GoalProjectionService.shared.generate(sourceImageURL: sourceURL)
                if case .success(let projectionURL) = outcome {
                    await MainActor.run {
                        self?.profile.goalProjectionURL = projectionURL
                        self?.profile.goalProjectionGeneratedAt = Date()
                        self?.saveProfile()
                    }
                }
            }
        }

        // Post to friends' activity feed (only for logged-in users with public/friends_only privacy).
        if currentUserId != nil {
            let score = result.overallScore
            Task.detached {
                await SocialService.shared.postActivity(
                    kind: "scan_completed",
                    payload: ["score": score]
                )
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
            currentUserId = session.user.id.uuidString.lowercased()
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
            // Check if returning user — restore from cloud FIRST, don't save to cloud
            let isReturning = await restoreFromCloud(userId: session.user.id.uuidString)
            if !isReturning {
                // New or deleted user — save locally only, onboarding will sync to cloud
                saveProfileLocally()
            }
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
            currentUserId = session.user.id.uuidString.lowercased()
            if let userEmail = session.user.email {
                profile.email = userEmail
            }
            if profile.name.isEmpty {
                profile.name = "Athlete"
            }
            // New signup — save locally only, onboarding will sync to cloud
            saveProfileLocally()
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
            currentUserId = session.user.id.uuidString.lowercased()
            if let userEmail = email ?? session.user.email {
                profile.email = userEmail
            }
            let meta = session.user.userMetadata
            let supabaseName = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue
            let appleName = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            let resolvedName = supabaseName ?? (appleName.isEmpty ? nil : appleName)
            profile.name = resolvedName ?? "Athlete"
            // Check if returning user — restore from cloud FIRST, don't save to cloud
            let isReturning = await restoreFromCloud(userId: session.user.id.uuidString)
            if !isReturning {
                saveProfileLocally()
            }
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
            currentUserId = session.user.id.uuidString.lowercased()
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
            // Check if returning user — restore from cloud FIRST, don't save to cloud
            let isReturning = await restoreFromCloud(userId: session.user.id.uuidString)
            if !isReturning {
                saveProfileLocally()
            }
        } catch {
            if (error as NSError).code == 1 {
                // user cancelled
            } else {
                authError = error.localizedDescription
            }
        }
        isAuthenticating = false
    }

    /// Save profile to UserDefaults only (no cloud sync).
    /// Used during sign-in to avoid creating a Supabase profile before onboarding completes.
    private func saveProfileLocally() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
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

        // Kill any workout Live Activity tied to this account before we
        // wipe local state — otherwise the lock screen shows the previous
        // user's session for hours after sign-out.
        WorkoutSessionManager.endAllActivities()

        // Step 2: On the next runloop tick, sign out and clear all local state.
        Task { @MainActor [weak self] in
            await PushNotificationService.shared.clearTokensForCurrentUser()
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
            ExerciseLogService.shared.clear()
            BodyMeasurementService.shared.clearLocal()
            RoutineService.shared.clearLocal()
            CustomExerciseService.shared.clearLocal()
            CoachViewModel.clearStorage()
            // Clear in-flight workout session so the next user signing in
            // on this device doesn't inherit a "Resume workout" pill.
            WorkoutSessionManager.clearPersistedSessionForLogout()
            // Reset widget shared defaults so the home-screen widget
            // doesn't keep flashing the prior user's data.
            UserDefaults.standard.removeObject(forKey: "widget_workoutName")
            UserDefaults.standard.removeObject(forKey: "widget_exerciseCount")
            UserDefaults.standard.removeObject(forKey: "widget_streak")
            UserDefaults.standard.removeObject(forKey: "widget_latestScore")
            WidgetCenter.shared.reloadAllTimelines()
            // Per-device flags that shouldn't bleed between users.
            UserDefaults.standard.removeObject(forKey: "healthConnected")
            UserDefaults.standard.removeObject(forKey: "notificationSettings")
            // Battle/profile photos belong to the user who signed in.
            try? FileManager.default.removeItem(at: AppState.battlePhotoURL)
            try? FileManager.default.removeItem(at: AppState.profilePhotoURL)
            self.profile = UserProfile()
            self.scanHistory = []
        }
    }

    func deleteAccount() async {
        // Mark this user ID as deleted BEFORE anything else — this ensures
        // restoreFromCloud will refuse to restore even if Supabase DELETE fails
        if let userId = currentUserId {
            markAccountDeleted(userId: userId)
            await SupabaseSyncService.shared.deleteProfile(userId: userId)
        }
        WorkoutSessionManager.endAllActivities()
        await PushNotificationService.shared.clearTokensForCurrentUser()
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
        ExerciseLogService.shared.clear()
        BodyMeasurementService.shared.clearLocal()
        RoutineService.shared.clearLocal()
        CustomExerciseService.shared.clearLocal()
        WorkoutSessionManager.clearPersistedSessionForLogout()
        UserDefaults.standard.removeObject(forKey: "widget_workoutName")
        UserDefaults.standard.removeObject(forKey: "widget_exerciseCount")
        UserDefaults.standard.removeObject(forKey: "widget_streak")
        UserDefaults.standard.removeObject(forKey: "widget_latestScore")
        WidgetCenter.shared.reloadAllTimelines()
        UserDefaults.standard.removeObject(forKey: "healthConnected")
        UserDefaults.standard.removeObject(forKey: "notificationSettings")
        // Remove profile and battle photos
        try? FileManager.default.removeItem(at: AppState.profilePhotoURL)
        try? FileManager.default.removeItem(at: AppState.battlePhotoURL)
        profile = UserProfile()
        scanHistory = []
    }

    // MARK: - Deleted Account Tracking

    /// Track deleted user IDs locally so restoreFromCloud refuses to restore
    /// data for a user that previously deleted their account on this device.
    /// This guards against Supabase DELETE failing silently due to RLS issues.
    private func markAccountDeleted(userId: String) {
        var deleted = UserDefaults.standard.stringArray(forKey: "deletedAccountIds") ?? []
        if !deleted.contains(userId) {
            deleted.append(userId)
            UserDefaults.standard.set(deleted, forKey: "deletedAccountIds")
        }
    }

    private func isAccountDeleted(userId: String) -> Bool {
        let deleted = UserDefaults.standard.stringArray(forKey: "deletedAccountIds") ?? []
        return deleted.contains(userId)
    }

    /// Called after a user successfully completes onboarding on a previously-deleted account.
    /// Removes them from the deleted list so future logins restore normally.
    private func clearDeletedMark(userId: String) {
        var deleted = UserDefaults.standard.stringArray(forKey: "deletedAccountIds") ?? []
        deleted.removeAll { $0 == userId }
        UserDefaults.standard.set(deleted, forKey: "deletedAccountIds")
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

        if profile.isPremium && profile.currentStreak > 0 && profile.currentStreak % 7 == 0 {
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

        // Post to friends' activity feed.
        if currentUserId != nil {
            let workoutName = dayName
            let exerciseCount = exercisesCompleted
            let totalCount = totalExercises
            let streak = profile.currentStreak
            Task.detached {
                await SocialService.shared.postActivity(
                    kind: "workout_completed",
                    payload: [
                        "workout_name": workoutName,
                        "exercises_completed": exerciseCount,
                        "total_exercises": totalCount
                    ]
                )
                // Streak milestones at 7 / 30 / 90 days
                if streak > 0 && (streak == 7 || streak == 30 || streak == 90 || streak % 100 == 0) {
                    await SocialService.shared.postActivity(
                        kind: "streak_milestone",
                        payload: ["streak": streak]
                    )
                }
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
        let rank = PhysiqueRank.rank(score: profile.latestScore, gender: profile.gender)
        profile.tier = rank.rawValue
    }
}
