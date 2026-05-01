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
        guard let url = URL(string: "\(baseURL)/user_profiles?id=eq.\(userId)&select=*&limit=1") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let profiles = try? JSONDecoder().decode([RemoteUserProfile].self, from: data),
              let profile = profiles.first else {
            return nil
        }
        return profile
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

        let body: [String: Any?] = [
            "id": userId,
            "name": profile.name,
            "username": profile.username,
            "email": profile.email,
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
            "has_completed_onboarding": hasCompletedOnboarding
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
            "core": entry.muscleScores.core
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

    // MARK: - Account Deletion

    /// Delete all user data from Supabase (profile, scans, workout logs).
    func deleteProfile(userId: String) async {
        let tables = ["workout_logs", "scan_history", "leaderboard_profiles", "user_profiles"]
        let headers = await authHeaders()

        for table in tables {
            guard let url = URL(string: "\(baseURL)/\(table)?id=eq.\(userId)") else { continue }
            var request = URLRequest(url: url)
            // user_profiles and leaderboard_profiles use "id", others use "user_id"
            if table == "workout_logs" || table == "scan_history" {
                guard let altUrl = URL(string: "\(baseURL)/\(table)?user_id=eq.\(userId)") else { continue }
                request = URLRequest(url: altUrl)
            }
            request.httpMethod = "DELETE"
            request.timeoutInterval = 15
            headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
            _ = try? await URLSession.shared.data(for: request)
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
        return p
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
                core: muscleScores["core"] ?? 0
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
