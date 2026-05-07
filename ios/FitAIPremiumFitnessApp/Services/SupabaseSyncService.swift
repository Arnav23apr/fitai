import Foundation
import Auth

/// Syncs user profile, scan history, and workout logs to Supabase.
/// Uses the same REST API pattern as LeaderboardService.
class SupabaseSyncService: @unchecked Sendable {
    static let shared = SupabaseSyncService()

    private let baseURL: String = Config.SUPABASE_URL + "/rest/v1"
    private let anonKey: String = Config.SUPABASE_ANON_KEY

    // MARK: - Auth token

    /// Get the current user's JWT for authenticated requests.
    /// Falls back to anon key if no session.
    private func authToken() async -> String {
        if let session = await SupabaseAuthService.shared.currentSession() {
            return session.accessToken
        }
        return anonKey
    }

    private func authHeaders() async -> [String: String] {
        let token = await authToken()
        return [
            "apikey": anonKey,
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
    }

    // MARK: - User Profile

    /// Check if a profile exists for the current user. Returns the profile if found.
    func fetchProfile(userId: String) async -> RemoteUserProfile? {
        switch await fetchProfileWithStatus(userId: userId) {
        case .found(let profile): return profile
        case .notFound, .failed:  return nil
        }
    }

    /// Like `fetchProfile` but distinguishes "row not found" (true new user)
    /// from "fetch failed" (network blip / decode error). Callers that hit
    /// `.failed` should preserve local state instead of treating the user
    /// as a new signup — that's the bug the tester hit when accounts
    /// "reset" on every Apple sign-in.
    enum FetchProfileStatus {
        case found(RemoteUserProfile)
        case notFound
        case failed(String)
    }

    func fetchProfileWithStatus(userId: String) async -> FetchProfileStatus {
        guard let url = URL(string: "\(baseURL)/user_profiles?id=eq.\(userId)&select=*&limit=1") else {
            return .failed("invalid url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Retry once on transient failure — Apple sign-in often races with
        // session being fully cookie'd up on the auth.users side.
        for attempt in 0..<2 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    return .failed("non-http response")
                }
                if http.statusCode == 200 {
                    do {
                        let profiles = try JSONDecoder().decode([RemoteUserProfile].self, from: data)
                        if let p = profiles.first {
                            return .found(p)
                        } else {
                            return .notFound
                        }
                    } catch {
                        #if DEBUG
                        print("[SupabaseSync] fetchProfile decode error: \(error)")
                        if let s = String(data: data, encoding: .utf8) {
                            print("[SupabaseSync] body: \(s.prefix(500))")
                        }
                        #endif
                        return .failed("decode: \(error.localizedDescription)")
                    }
                }
                // 4xx — likely RLS or auth issue, treat as failed (don't reset user).
                if http.statusCode >= 400 {
                    #if DEBUG
                    print("[SupabaseSync] fetchProfile HTTP \(http.statusCode)")
                    #endif
                    if attempt == 1 {
                        return .failed("http \(http.statusCode)")
                    }
                }
            } catch {
                if attempt == 1 {
                    return .failed("network: \(error.localizedDescription)")
                }
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        return .failed("retries exhausted")
    }

    /// Check if a username is available. Pass the current user's id to allow them
    /// to keep their own existing username. Returns true if free to use, false if taken,
    /// nil if the network request failed (caller decides how to surface ambiguity).
    func isUsernameAvailable(_ username: String, excludingUserId: String?) async -> Bool? {
        let normalized = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty,
              let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/user_profiles?username=eq.\(encoded)&select=id&limit=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let rows = try? JSONDecoder().decode([UsernameRow].self, from: data) else {
            return nil
        }
        guard let owner = rows.first?.id else { return true }
        return owner == excludingUserId
    }

    /// Upsert (insert or update) the user profile.
    func upsertProfile(userId: String, profile: UserProfile, hasCompletedOnboarding: Bool) async {
        guard let url = URL(string: "\(baseURL)/user_profiles") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Identity fields are NOT sent in the bulk profile sync. They have
        // their own dedicated paths: username via `setUsername(...)` (called
        // explicitly when the user picks/edits a username), email/name
        // populated server-side at signup. Sending them here would clobber
        // good remote values whenever the local profile happens to be stale
        // (fresh launch before restoreFromCloud, etc.).
        let body: [String: Any?] = [
            "id": userId,
            // name / username / email intentionally omitted — see comment above.
            "bio": profile.bio,
            "avatar_system_name": profile.avatarSystemName,
            "gender": profile.gender,
            "date_of_birth": profile.dateOfBirth.map { ISO8601DateFormatter().string(from: $0) },
            "height_cm": profile.heightCm,
            "weight_kg": profile.weightKg,
            "uses_metric": profile.usesMetric,
            "selected_language": profile.selectedLanguage,
            "force_dark_mode": profile.forceDarkMode,
            "workouts_per_week": profile.workoutsPerWeek,
            "training_experience": profile.trainingExperience,
            "training_location": profile.trainingLocation,
            "training_confidence": profile.trainingConfidence,
            "primary_goal": profile.primaryGoal,
            "holding_back": profile.holdingBack,
            "goals": profile.goals,
            "referral_code": profile.referralCode,
            "referred_by_code": profile.referredByCode,
            "friends_referred_count": profile.friendsReferredCount,
            "privacy_mode": profile.privacyMode,
            "allow_username_search": profile.allowUsernameSearch,
            "username_changed_at": profile.usernameChangedAt.map { ISO8601DateFormatter().string(from: $0) },
            "is_premium": profile.isPremium,
            "spin_discount": profile.spinDiscount,
            "free_scans_earned": profile.freeScansEarned,
            "total_scans": profile.totalScans,
            "total_workouts": profile.totalWorkouts,
            "current_streak": profile.currentStreak,
            "points": profile.points,
            "tier": profile.tier,
            "latest_score": profile.latestScore,
            "last_scan_date": profile.lastScanDate.map { ISO8601DateFormatter().string(from: $0) },
            "weak_points": profile.weakPoints,
            "strong_points": profile.strongPoints,
            "completed_days_this_week": profile.completedDaysThisWeek,
            "week_start_date": profile.weekStartDate.map { ISO8601DateFormatter().string(from: $0) },
            "has_completed_onboarding": hasCompletedOnboarding,
            // Profile fields that were previously dropped on sync — closes
            // the persistence audit gap (photo consent, equipment list,
            // AI chat quota counter, photo improvement opt-in).
            "photo_consent_version": profile.photoConsentVersion,
            "photo_consent_granted_at": profile.photoConsentGrantedAt.map { ISO8601DateFormatter().string(from: $0) },
            "available_equipment": profile.availableEquipment,
            "ai_chat_messages_used": profile.aiChatMessagesUsed,
            "photo_improvement_opt_in": profile.photoImprovementOptIn,
            "profile_photo_url": profile.profilePhotoURL
        ]

        // Filter out nil values for JSON serialization
        let filtered = body.compactMapValues { $0 }
        request.httpBody = try? JSONSerialization.data(withJSONObject: filtered)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] upsertProfile failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] upsertProfile error: \(error.localizedDescription)")
            #endif
        }
    }

    /// Explicitly write identity fields (name / username / email) to the
    /// user's profile. Called only when the user deliberately changes them
    /// (Profile → Edit). Bulk profile sync via `upsertProfile` deliberately
    /// skips these to avoid clobbering good remote values.
    func setIdentity(userId: String, name: String?, username: String?, email: String?) async {
        guard let url = URL(string: "\(baseURL)/user_profiles?id=eq.\(userId)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "return=minimal"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        var body: [String: Any] = [:]
        if let n = name, !n.isEmpty { body["name"] = n }
        if let u = username, !u.isEmpty { body["username"] = u }
        if let e = email, !e.isEmpty { body["email"] = e }
        guard !body.isEmpty else { return }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] setIdentity failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] setIdentity error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Referrals

    /// Calls the `claim_referral` Postgres RPC to attribute this signup to the
    /// user owning `referrerCode`. Server uses `auth.uid()` for the referred user.
    /// Idempotent: subsequent calls for the same referred user are no-ops.
    /// Each 3rd referral grants the referrer `+1 free_scans_earned`.
    func claimReferral(referredUserId: String, referrerCode: String) async {
        guard let url = URL(string: "\(baseURL)/rpc/claim_referral") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any] = ["p_referrer_code": referrerCode]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] claimReferral failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] claimReferral error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Scan History

    /// Fetch all scan history for a user.
    func fetchScanHistory(userId: String) async -> [RemoteScanEntry] {
        guard let url = URL(string: "\(baseURL)/scan_history?user_id=eq.\(userId)&select=*&order=date.desc&limit=50") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let entries = try? JSONDecoder().decode([RemoteScanEntry].self, from: data) else {
            return []
        }
        return entries
    }

    /// Insert a single scan entry.
    func insertScan(userId: String, entry: ScanHistoryEntry) async {
        guard let url = URL(string: "\(baseURL)/scan_history") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let scores: [String: Double] = [
            "chest": entry.muscleScores.chest,
            "shoulders": entry.muscleScores.shoulders,
            "back": entry.muscleScores.back,
            "arms": entry.muscleScores.arms,
            "legs": entry.muscleScores.legs,
            "core": entry.muscleScores.core,
            "glutes": entry.muscleScores.glutes ?? 0
        ]

        let body: [String: Any] = [
            "id": entry.id,
            "user_id": userId,
            "date": ISO8601DateFormatter().string(from: entry.date),
            "overall_score": entry.overallScore,
            "potential_rating": entry.potentialRating,
            "muscle_mass_rating": entry.muscleMassRating,
            "strong_points": entry.strongPoints,
            "weak_points": entry.weakPoints,
            "summary": entry.summary,
            "recommendations": entry.recommendations,
            "muscle_scores": scores
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] insertScan failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] insertScan error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Workout Logs

    /// Fetch all workout logs for a user.
    func fetchWorkoutLogs(userId: String) async -> [RemoteWorkoutLog] {
        guard let url = URL(string: "\(baseURL)/workout_logs?user_id=eq.\(userId)&select=*&order=date.desc") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let logs = try? JSONDecoder().decode([RemoteWorkoutLog].self, from: data) else {
            return []
        }
        return logs
    }

    /// Insert a single workout log.
    func insertWorkoutLog(userId: String, log: WorkoutLog) async {
        guard let url = URL(string: "\(baseURL)/workout_logs") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any] = [
            "id": log.id,
            "user_id": userId,
            "date": ISO8601DateFormatter().string(from: log.date),
            "day_name": log.dayName,
            "exercises_completed": log.exercisesCompleted,
            "total_exercises": log.totalExercises,
            "duration_minutes": log.durationMinutes,
            "completed_exercise_names": log.completedExerciseNames
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] insertWorkoutLog failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] insertWorkoutLog error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Exercise Logs (per-set workout detail)

    /// Fetch all exercise logs for a user, newest first. Cap at 1000 to
    /// match the local `ExerciseLogService` ceiling.
    func fetchExerciseLogs(userId: String) async -> [RemoteExerciseLog] {
        guard let url = URL(string: "\(baseURL)/exercise_logs?user_id=eq.\(userId)&select=*&order=date.desc&limit=1000") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let logs = try? JSONDecoder().decode([RemoteExerciseLog].self, from: data) else {
            return []
        }
        return logs
    }

    /// Insert/upsert a single exercise log. The full set list is encoded
    /// as jsonb so any future SetLog field additions don't require a
    /// schema migration.
    func insertExerciseLog(userId: String, log: ExerciseLog) async {
        guard let url = URL(string: "\(baseURL)/exercise_logs") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Encode sets as JSON array of dictionaries to land cleanly in jsonb.
        let setsArray: [[String: Any]] = log.sets.map { s in
            [
                "id": s.id,
                "weight": s.weight,
                "reps": s.reps,
                "isCompleted": s.isCompleted,
                "isFailure": s.isFailure,
                "isDropSet": s.isDropSet,
                "isBodyweight": s.isBodyweight,
                "timestamp": ISO8601DateFormatter().string(from: s.timestamp)
            ]
        }

        let body: [String: Any] = [
            "id": log.id,
            "user_id": userId,
            "exercise_name": log.exerciseName,
            "muscle_group": log.muscleGroup,
            "date": ISO8601DateFormatter().string(from: log.date),
            "sets": setsArray,
            "total_volume": log.totalVolume
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] insertExerciseLog failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] insertExerciseLog error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Body Measurements

    func fetchBodyMeasurements(userId: String) async -> [RemoteBodyMeasurement] {
        guard let url = URL(string: "\(baseURL)/body_measurements?user_id=eq.\(userId)&select=*&order=date.desc") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let rows = try? JSONDecoder().decode([RemoteBodyMeasurement].self, from: data) else {
            return []
        }
        return rows
    }

    func upsertBodyMeasurement(userId: String, measurement: BodyMeasurement) async {
        guard let url = URL(string: "\(baseURL)/body_measurements") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any?] = [
            "id": measurement.id,
            "user_id": userId,
            "date": ISO8601DateFormatter().string(from: measurement.date),
            "weight_kg": measurement.weightKg,
            "chest_cm": measurement.chestCm,
            "waist_cm": measurement.waistCm,
            "hips_cm": measurement.hipsCm,
            "left_arm_cm": measurement.leftArmCm,
            "right_arm_cm": measurement.rightArmCm,
            "left_thigh_cm": measurement.leftThighCm,
            "right_thigh_cm": measurement.rightThighCm,
            "left_calf_cm": measurement.leftCalfCm,
            "right_calf_cm": measurement.rightCalfCm,
            "neck_cm": measurement.neckCm,
            "shoulders_cm": measurement.shouldersCm,
            "notes": measurement.notes
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] upsertBodyMeasurement failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] upsertBodyMeasurement error: \(error.localizedDescription)")
            #endif
        }
    }

    func deleteBodyMeasurement(userId: String, id: String) async {
        guard let url = URL(string: "\(baseURL)/body_measurements?id=eq.\(id)&user_id=eq.\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - User Routines

    /// Fetch all custom routines for a user. The payload column is opaque
    /// jsonb — we round-trip the full Routine struct via JSONEncoder.
    func fetchRoutines(userId: String) async -> [Routine] {
        guard let url = URL(string: "\(baseURL)/user_routines?user_id=eq.\(userId)&select=*&order=updated_at.desc") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let rows = try? JSONDecoder().decode([RemoteRoutineRow].self, from: data) else {
            return []
        }
        // Each row's `payload` is the full Routine encoded as a json blob.
        return rows.compactMap { row in
            guard let payloadData = try? JSONSerialization.data(withJSONObject: row.payload) else { return nil }
            return try? JSONDecoder().decode(Routine.self, from: payloadData)
        }
    }

    func upsertRoutine(userId: String, routine: Routine) async {
        guard let url = URL(string: "\(baseURL)/user_routines") else { return }
        guard let payloadData = try? JSONEncoder().encode(routine),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any] = [
            "id": routine.id,
            "user_id": userId,
            "payload": payloadJSON,
            "updated_at": ISO8601DateFormatter().string(from: routine.updatedAt)
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] upsertRoutine failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] upsertRoutine error: \(error.localizedDescription)")
            #endif
        }
    }

    func deleteRoutine(userId: String, id: String) async {
        guard let url = URL(string: "\(baseURL)/user_routines?id=eq.\(id)&user_id=eq.\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Custom Exercises

    func fetchCustomExercises(userId: String) async -> [CustomExercise] {
        guard let url = URL(string: "\(baseURL)/custom_exercises?user_id=eq.\(userId)&select=*&order=created_at.desc") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let rows = try? JSONDecoder().decode([RemoteCustomExercise].self, from: data) else {
            return []
        }
        return rows.compactMap { $0.toCustomExercise() }
    }

    func upsertCustomExercise(userId: String, exercise: CustomExercise) async {
        guard let url = URL(string: "\(baseURL)/custom_exercises") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "resolution=merge-duplicates"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any] = [
            "id": exercise.id,
            "user_id": userId,
            "name": exercise.name,
            "primary_muscle": exercise.primaryMuscle,
            "secondary_muscles": exercise.secondaryMuscles,
            "notes": exercise.notes,
            "created_at": ISO8601DateFormatter().string(from: exercise.createdAt)
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                print("[SupabaseSync] upsertCustomExercise failed: HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[SupabaseSync] upsertCustomExercise error: \(error.localizedDescription)")
            #endif
        }
    }

    func deleteCustomExercise(userId: String, id: String) async {
        guard let url = URL(string: "\(baseURL)/custom_exercises?id=eq.\(id)&user_id=eq.\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Presence (last_seen_at heartbeat)

    /// Bump `last_seen_at = now()` on the user's profile so friends see
    /// them as "online" in the next ~5 min window. Best-effort; failures
    /// are silent (offline / unauthenticated → just skip).
    func bumpLastSeen(userId: String) async {
        guard let url = URL(string: "\(baseURL)/user_profiles?id=eq.\(userId)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 10
        var headers = await authHeaders()
        headers["Prefer"] = "return=minimal"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any] = [
            "last_seen_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Notification Preferences (stored as jsonb on user_profiles)

    /// Patch just the notification_prefs column on user_profiles.
    func setNotificationPrefs(userId: String, prefs: [String: Any]) async {
        guard let url = URL(string: "\(baseURL)/user_profiles?id=eq.\(userId)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        var headers = await authHeaders()
        headers["Prefer"] = "return=minimal"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: Any] = ["notification_prefs": prefs]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Account Deletion

    /// Delete all user data from Supabase (profile, scans, workout logs).
    func deleteProfile(userId: String) async {
        // Order matters: delete dependent tables first, then user_profiles last
        let tables: [(name: String, column: String)] = [
            ("exercise_logs", "user_id"),
            ("body_measurements", "user_id"),
            ("user_routines", "user_id"),
            ("custom_exercises", "user_id"),
            ("workout_logs", "user_id"),
            ("scan_history", "user_id"),
            ("leaderboard_profiles", "id"),
            ("user_profiles", "id"),
        ]
        let headers = await authHeaders()

        for table in tables {
            guard let url = URL(string: "\(baseURL)/\(table.name)?\(table.column)=eq.\(userId)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.timeoutInterval = 15
            headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                #if DEBUG
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    print("[SupabaseSync] DELETE \(table.name) failed: HTTP \(http.statusCode)")
                }
                #endif
            } catch {
                #if DEBUG
                print("[SupabaseSync] DELETE \(table.name) error: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

private struct UsernameRow: Decodable {
    let id: String
}

// MARK: - Remote DTOs (match Supabase snake_case columns)

struct RemoteUserProfile: Codable {
    let id: String
    let name: String
    let username: String
    let email: String
    let bio: String
    let avatarSystemName: String
    let gender: String
    let dateOfBirth: String?
    let heightCm: Double
    let weightKg: Double
    let usesMetric: Bool
    let selectedLanguage: String
    let forceDarkMode: Bool
    let workoutsPerWeek: Int
    let trainingExperience: String
    let trainingLocation: String
    let trainingConfidence: Int
    let primaryGoal: String
    let holdingBack: [String]
    let goals: [String]
    let referralCode: String
    let referredByCode: String?
    let friendsReferredCount: Int?
    let privacyMode: String?
    let allowUsernameSearch: Bool?
    let usernameChangedAt: String?
    let isPremium: Bool
    let spinDiscount: Int?
    let freeScansEarned: Int
    let totalScans: Int
    let totalWorkouts: Int
    let currentStreak: Int
    let points: Int
    let tier: String
    let latestScore: Double?
    let lastScanDate: String?
    let weakPoints: [String]
    let strongPoints: [String]
    let completedDaysThisWeek: [String]
    let weekStartDate: String?
    let hasCompletedOnboarding: Bool
    let goalProjectionURL: String?
    let goalProjectionGeneratedAt: String?
    // Profile fields previously dropped on sync — added in migration 017.
    // Optional so older rows (pre-migration) decode cleanly.
    let photoConsentVersion: Int?
    let photoConsentGrantedAt: String?
    let availableEquipment: [String]?
    let aiChatMessagesUsed: Int?
    let photoImprovementOptIn: Bool?
    let profilePhotoURL: String?
    let notificationPrefs: [String: JSONCodable]?

    enum CodingKeys: String, CodingKey {
        case id, name, username, email, bio, gender, points, tier
        case avatarSystemName = "avatar_system_name"
        case dateOfBirth = "date_of_birth"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case usesMetric = "uses_metric"
        case selectedLanguage = "selected_language"
        case forceDarkMode = "force_dark_mode"
        case workoutsPerWeek = "workouts_per_week"
        case trainingExperience = "training_experience"
        case trainingLocation = "training_location"
        case trainingConfidence = "training_confidence"
        case primaryGoal = "primary_goal"
        case holdingBack = "holding_back"
        case goals
        case referralCode = "referral_code"
        case referredByCode = "referred_by_code"
        case friendsReferredCount = "friends_referred_count"
        case privacyMode = "privacy_mode"
        case allowUsernameSearch = "allow_username_search"
        case usernameChangedAt = "username_changed_at"
        case isPremium = "is_premium"
        case spinDiscount = "spin_discount"
        case freeScansEarned = "free_scans_earned"
        case totalScans = "total_scans"
        case totalWorkouts = "total_workouts"
        case currentStreak = "current_streak"
        case latestScore = "latest_score"
        case lastScanDate = "last_scan_date"
        case weakPoints = "weak_points"
        case strongPoints = "strong_points"
        case completedDaysThisWeek = "completed_days_this_week"
        case weekStartDate = "week_start_date"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case goalProjectionURL = "goal_projection_url"
        case goalProjectionGeneratedAt = "goal_projection_generated_at"
        case photoConsentVersion = "photo_consent_version"
        case photoConsentGrantedAt = "photo_consent_granted_at"
        case availableEquipment = "available_equipment"
        case aiChatMessagesUsed = "ai_chat_messages_used"
        case photoImprovementOptIn = "photo_improvement_opt_in"
        case profilePhotoURL = "profile_photo_url"
        case notificationPrefs = "notification_prefs"
    }

    /// Convert to local UserProfile
    func toUserProfile() -> UserProfile {
        let iso = ISO8601DateFormatter()
        var p = UserProfile()
        p.name = name
        p.username = username
        p.email = email
        p.bio = bio
        p.avatarSystemName = avatarSystemName
        p.gender = gender
        p.dateOfBirth = dateOfBirth.flatMap { iso.date(from: $0) }
        p.heightCm = heightCm
        p.weightKg = weightKg
        p.usesMetric = usesMetric
        p.selectedLanguage = selectedLanguage
        p.forceDarkMode = forceDarkMode
        p.workoutsPerWeek = workoutsPerWeek
        p.trainingExperience = trainingExperience
        p.trainingLocation = trainingLocation
        p.trainingConfidence = trainingConfidence
        p.primaryGoal = primaryGoal
        p.holdingBack = holdingBack
        p.goals = goals
        p.referralCode = referralCode
        p.referredByCode = referredByCode ?? ""
        p.friendsReferredCount = friendsReferredCount ?? 0
        p.privacyMode = privacyMode ?? "public"
        p.allowUsernameSearch = allowUsernameSearch ?? true
        p.usernameChangedAt = usernameChangedAt.flatMap { iso.date(from: $0) }
        p.isPremium = isPremium
        p.spinDiscount = spinDiscount
        p.freeScansEarned = freeScansEarned
        p.totalScans = totalScans
        p.totalWorkouts = totalWorkouts
        p.currentStreak = currentStreak
        p.points = points
        p.tier = tier
        p.latestScore = latestScore
        p.lastScanDate = lastScanDate.flatMap { iso.date(from: $0) }
        p.weakPoints = weakPoints
        p.strongPoints = strongPoints
        p.completedDaysThisWeek = completedDaysThisWeek
        p.weekStartDate = weekStartDate.flatMap { iso.date(from: $0) }
        p.goalProjectionURL = goalProjectionURL
        p.goalProjectionGeneratedAt = goalProjectionGeneratedAt.flatMap { iso.date(from: $0) }
        // Restore previously-dropped fields (default to local model defaults
        // for older rows missing these columns).
        if let v = photoConsentVersion       { p.photoConsentVersion = v }
        if let d = photoConsentGrantedAt     { p.photoConsentGrantedAt = iso.date(from: d) }
        if let eq = availableEquipment       { p.availableEquipment = eq }
        if let used = aiChatMessagesUsed     { p.aiChatMessagesUsed = used }
        if let opt = photoImprovementOptIn   { p.photoImprovementOptIn = opt }
        p.profilePhotoURL = profilePhotoURL
        return p
    }
}

/// Lightweight `Any`-equivalent for the `notification_prefs` jsonb column.
/// Decodes any JSON value; `value` is the underlying scalar/array/dict.
struct JSONCodable: Codable {
    let value: Any?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = nil; return }
        if let b = try? c.decode(Bool.self)         { value = b; return }
        if let i = try? c.decode(Int.self)          { value = i; return }
        if let d = try? c.decode(Double.self)       { value = d; return }
        if let s = try? c.decode(String.self)       { value = s; return }
        if let arr = try? c.decode([JSONCodable].self) {
            value = arr.map { $0.value as Any }; return
        }
        if let obj = try? c.decode([String: JSONCodable].self) {
            value = obj.mapValues { $0.value as Any }; return
        }
        value = nil
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case nil: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        default: try c.encodeNil()
        }
    }
}

struct RemoteScanEntry: Codable {
    let id: String
    let date: String
    let overallScore: Double
    let potentialRating: Double
    let muscleMassRating: String
    let strongPoints: [String]
    let weakPoints: [String]
    let summary: String
    let recommendations: [String]
    let muscleScores: [String: Double]

    enum CodingKeys: String, CodingKey {
        case id, date, summary, recommendations
        case overallScore = "overall_score"
        case potentialRating = "potential_rating"
        case muscleMassRating = "muscle_mass_rating"
        case strongPoints = "strong_points"
        case weakPoints = "weak_points"
        case muscleScores = "muscle_scores"
    }

    func toScanHistoryEntry() -> ScanHistoryEntry? {
        guard let parsedDate = ISO8601DateFormatter().date(from: date) else { return nil }
        let scores = CodableMuscleScores(
            from: MuscleScores(
                chest: muscleScores["chest"] ?? 0,
                shoulders: muscleScores["shoulders"] ?? 0,
                back: muscleScores["back"] ?? 0,
                arms: muscleScores["arms"] ?? 0,
                legs: muscleScores["legs"] ?? 0,
                core: muscleScores["core"] ?? 0,
                glutes: muscleScores["glutes"] ?? 0
            )
        )
        return ScanHistoryEntry(
            id: id,
            date: parsedDate,
            overallScore: overallScore,
            potentialRating: potentialRating,
            muscleMassRating: muscleMassRating,
            strongPoints: strongPoints,
            weakPoints: weakPoints,
            summary: summary,
            recommendations: recommendations,
            muscleScores: scores
        )
    }
}

struct RemoteWorkoutLog: Codable {
    let id: String
    let date: String
    let dayName: String
    let exercisesCompleted: Int
    let totalExercises: Int
    let durationMinutes: Int
    let completedExerciseNames: [String]

    enum CodingKeys: String, CodingKey {
        case id, date
        case dayName = "day_name"
        case exercisesCompleted = "exercises_completed"
        case totalExercises = "total_exercises"
        case durationMinutes = "duration_minutes"
        case completedExerciseNames = "completed_exercise_names"
    }

    func toWorkoutLog() -> WorkoutLog? {
        guard let parsedDate = ISO8601DateFormatter().date(from: date) else { return nil }
        return WorkoutLog(
            id: id,
            date: parsedDate,
            dayName: dayName,
            exercisesCompleted: exercisesCompleted,
            totalExercises: totalExercises,
            durationMinutes: durationMinutes,
            completedExerciseNames: completedExerciseNames
        )
    }
}

// MARK: - Exercise log DTO (per-set workout detail)

struct RemoteExerciseLog: Codable {
    let id: String
    let exerciseName: String
    let muscleGroup: String
    let date: String
    let sets: [RemoteSetLog]
    let totalVolume: Double

    enum CodingKeys: String, CodingKey {
        case id, date, sets
        case exerciseName = "exercise_name"
        case muscleGroup = "muscle_group"
        case totalVolume = "total_volume"
    }

    func toExerciseLog() -> ExerciseLog? {
        guard let parsedDate = ISO8601DateFormatter().date(from: date) else { return nil }
        let setLogs = sets.map { $0.toSetLog() }
        return ExerciseLog(
            id: id,
            exerciseName: exerciseName,
            muscleGroup: muscleGroup,
            date: parsedDate,
            sets: setLogs,
            totalVolume: totalVolume
        )
    }
}

struct RemoteSetLog: Codable {
    let id: String
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    let isFailure: Bool?
    let isDropSet: Bool?
    let isBodyweight: Bool?
    let timestamp: String?

    func toSetLog() -> SetLog {
        let ts = timestamp.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        return SetLog(
            id: id,
            weight: weight,
            reps: reps,
            isCompleted: isCompleted,
            isFailure: isFailure ?? false,
            isDropSet: isDropSet ?? false,
            isBodyweight: isBodyweight ?? false,
            timestamp: ts
        )
    }
}

// MARK: - Body measurement DTO

struct RemoteBodyMeasurement: Codable {
    let id: String
    let date: String
    let weightKg: Double?
    let chestCm: Double?
    let waistCm: Double?
    let hipsCm: Double?
    let leftArmCm: Double?
    let rightArmCm: Double?
    let leftThighCm: Double?
    let rightThighCm: Double?
    let leftCalfCm: Double?
    let rightCalfCm: Double?
    let neckCm: Double?
    let shouldersCm: Double?
    let notes: String

    enum CodingKeys: String, CodingKey {
        case id, date, notes
        case weightKg = "weight_kg"
        case chestCm = "chest_cm"
        case waistCm = "waist_cm"
        case hipsCm = "hips_cm"
        case leftArmCm = "left_arm_cm"
        case rightArmCm = "right_arm_cm"
        case leftThighCm = "left_thigh_cm"
        case rightThighCm = "right_thigh_cm"
        case leftCalfCm = "left_calf_cm"
        case rightCalfCm = "right_calf_cm"
        case neckCm = "neck_cm"
        case shouldersCm = "shoulders_cm"
    }

    func toBodyMeasurement() -> BodyMeasurement? {
        guard let parsedDate = ISO8601DateFormatter().date(from: date) else { return nil }
        return BodyMeasurement(
            id: id,
            date: parsedDate,
            weightKg: weightKg,
            chestCm: chestCm,
            waistCm: waistCm,
            hipsCm: hipsCm,
            leftArmCm: leftArmCm,
            rightArmCm: rightArmCm,
            leftThighCm: leftThighCm,
            rightThighCm: rightThighCm,
            leftCalfCm: leftCalfCm,
            rightCalfCm: rightCalfCm,
            neckCm: neckCm,
            shouldersCm: shouldersCm,
            notes: notes
        )
    }
}

// MARK: - Custom exercise DTO

struct RemoteCustomExercise: Codable {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let notes: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
        case createdAt = "created_at"
    }

    func toCustomExercise() -> CustomExercise? {
        let date = ISO8601DateFormatter().date(from: createdAt) ?? Date()
        return CustomExercise(
            id: id,
            name: name,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            notes: notes,
            createdAt: date
        )
    }
}

// MARK: - Routine row DTO (payload is opaque jsonb)

struct RemoteRoutineRow: Decodable {
    let id: String
    let payload: [String: Any]

    private enum CodingKeys: String, CodingKey {
        case id, payload
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        // Decode payload as raw Data then re-parse to [String: Any]; the
        // Routine value itself round-trips through JSONEncoder/Decoder
        // upstream in `fetchRoutines`.
        let raw = try c.decode(JSONValue.self, forKey: .payload)
        self.payload = (raw.toAny() as? [String: Any]) ?? [:]
    }
}

/// Tiny helper to decode arbitrary JSON into `Any` for jsonb round-trips.
private indirect enum JSONValue: Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    func toAny() -> Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let a): return a.map { $0.toAny() }
        case .object(let o): return o.mapValues { $0.toAny() }
        }
    }
}
