import Foundation

nonisolated struct LeaderboardProfile: Codable, Identifiable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let points: Int
    let tier: String
    let streak: Int
    let totalWorkouts: Int
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case points
        case tier
        case streak
        case totalWorkouts = "total_workouts"
        case updatedAt = "updated_at"
    }
}

nonisolated class LeaderboardService: @unchecked Sendable {
    static let shared = LeaderboardService()

    private let baseURL: String = Config.SUPABASE_URL + "/rest/v1"
    private let anonKey: String = Config.SUPABASE_ANON_KEY

    private var commonHeaders: [String: String] {
        [
            "apikey": anonKey,
            "Authorization": "Bearer \(anonKey)",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        ]
    }

    func upsertProfile(username: String, displayName: String, points: Int, tier: String, streak: Int, totalWorkouts: Int) async {
        guard !username.isEmpty else { return }
        guard let url = URL(string: "\(baseURL)/leaderboard_profiles") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        commonHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "username": username.lowercased(),
            "display_name": displayName.isEmpty ? username : displayName,
            "points": points,
            "tier": tier,
            "streak": streak,
            "total_workouts": totalWorkouts
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    func fetchLeaderboard(limit: Int = 50) async -> [LeaderboardProfile] {
        guard let url = URL(string: "\(baseURL)/leaderboard_profiles?select=*&order=points.desc&limit=\(limit)") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        ["apikey": anonKey, "Authorization": "Bearer \(anonKey)"].forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let profiles = try? JSONDecoder().decode([LeaderboardProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    func searchUser(username: String) async -> LeaderboardProfile? {
        let query = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/leaderboard_profiles?username=eq.\(encoded)&select=*&limit=1") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        ["apikey": anonKey, "Authorization": "Bearer \(anonKey)"].forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let profiles = try? JSONDecoder().decode([LeaderboardProfile].self, from: data),
              let profile = profiles.first else {
            return nil
        }
        return profile
    }

    func fetchUserRank(username: String) async -> Int? {
        let query = username.lowercased()
        let all = await fetchLeaderboard(limit: 500)
        return all.firstIndex(where: { $0.username == query }).map { $0 + 1 }
    }
}
