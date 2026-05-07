import Foundation
import Auth

/// Social spine: friend requests, friendships, challenges, blocks, reports,
/// notifications, activity feed, group challenges. All mutating operations
/// go through SECURITY DEFINER RPCs (see supabase/migrations/003_social.sql).
final class SocialService: @unchecked Sendable {
    static let shared = SocialService()

    private let baseURL: String = Config.SUPABASE_URL + "/rest/v1"
    private let anonKey: String = Config.SUPABASE_ANON_KEY

    // MARK: - Auth headers

    private func authHeaders() async -> [String: String] {
        var token = anonKey
        if let session = await SupabaseAuthService.shared.currentSession() {
            token = session.accessToken
        }
        return [
            "apikey": anonKey,
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
    }

    private func rpc(_ name: String, body: [String: Any]) async -> RPCResult {
        guard let url = URL(string: "\(baseURL)/rpc/\(name)") else {
            return .failure("invalid_url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("no_response")
            }
            if http.statusCode >= 400 {
                let body = String(data: data, encoding: .utf8) ?? ""
                return .failure("http_\(http.statusCode): \(body)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let ok = json["ok"] as? Bool, !ok {
                    let reason = json["reason"] as? String ?? "unknown"
                    return .softFailure(reason: reason, raw: json)
                }
                return .success(json)
            }
            return .success([:])
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func get<T: Decodable>(_ path: String, as type: T.Type) async -> T? {
        guard let url = URL(string: "\(baseURL)/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: - Username uniqueness (live availability check)

    /// Returns true if the username is free OR currently belongs to `currentUserId`.
    /// Returns nil if the request couldn't be performed (offline, etc).
    func isUsernameAvailable(_ username: String, currentUserId: String?) async -> Bool? {
        let normalized = username
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 3,
              let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let path = "user_profiles?username=eq.\(encoded)&select=id&limit=1"
        guard let rows: [UsernameAvailabilityRow] = await get(path, as: [UsernameAvailabilityRow].self) else {
            return nil
        }
        guard let owner = rows.first?.id else { return true }
        return owner == currentUserId
    }

    // MARK: - Friend requests + friendships

    @discardableResult
    func sendFriendRequest(toUsername: String) async -> RPCResult {
        await rpc("send_friend_request", body: ["p_to_username": toUsername])
    }

    @discardableResult
    func respondFriendRequest(requestId: String, accept: Bool) async -> RPCResult {
        await rpc("respond_friend_request", body: [
            "p_request_id": requestId,
            "p_accept": accept
        ])
    }

    @discardableResult
    func cancelFriendRequest(requestId: String) async -> RPCResult {
        await rpc("cancel_friend_request", body: ["p_request_id": requestId])
    }

    @discardableResult
    func removeFriendship(otherUserId: String) async -> RPCResult {
        await rpc("remove_friendship", body: ["p_other_user_id": otherUserId])
    }

    /// Pending requests addressed to the current user.
    func fetchIncomingRequests(myUserId: String) async -> [FriendRequestRow] {
        let path = "friend_requests?to_user_id=eq.\(myUserId)&status=eq.pending&select=*&order=created_at.desc"
        return await get(path, as: [FriendRequestRow].self) ?? []
    }

    /// Pending requests sent by the current user.
    func fetchOutgoingRequests(myUserId: String) async -> [FriendRequestRow] {
        let path = "friend_requests?from_user_id=eq.\(myUserId)&status=eq.pending&select=*&order=created_at.desc"
        return await get(path, as: [FriendRequestRow].self) ?? []
    }

    /// Accepted friendships involving the current user — returns the OTHER user id.
    func fetchFriendships(myUserId: String) async -> [FriendshipRow] {
        let pathA = "friendships?user_a=eq.\(myUserId)&select=*"
        let pathB = "friendships?user_b=eq.\(myUserId)&select=*"
        async let aSide: [FriendshipRow]? = get(pathA, as: [FriendshipRow].self)
        async let bSide: [FriendshipRow]? = get(pathB, as: [FriendshipRow].self)
        let a = await aSide ?? []
        let b = await bSide ?? []
        return (a + b).sorted { $0.createdAt > $1.createdAt }
    }

    /// Lookup user profiles for a list of ids.
    func fetchProfilesByIds(_ ids: [String]) async -> [String: SocialProfileSummary] {
        guard !ids.isEmpty,
              let url = URL(string: "\(baseURL)/user_profiles?id=in.(\(ids.joined(separator: ",")))&select=id,username,name,avatar_system_name,profile_photo_url,tier,points,total_workouts,current_streak,latest_score,privacy_mode,last_seen_at") else {
            return [:]
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let rows = try? JSONDecoder().decode([SocialProfileSummary].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    /// Fetch a single friend's full profile (includes bio and richer fields
    /// not exposed by the leaderboard summary). Used by FriendProfileSheet.
    func fetchProfileDetail(userId: String) async -> FriendProfileDetail? {
        let path = "user_profiles?id=eq.\(userId)&select=id,username,name,bio,avatar_system_name,profile_photo_url,tier,points,total_workouts,current_streak,latest_score,privacy_mode&limit=1"
        let rows: [FriendProfileDetail] = await get(path, as: [FriendProfileDetail].self) ?? []
        return rows.first
    }

    // MARK: - Blocks + reports

    @discardableResult
    func blockUser(otherUserId: String) async -> RPCResult {
        await rpc("block_user", body: ["p_other_user_id": otherUserId])
    }

    @discardableResult
    func unblockUser(otherUserId: String) async -> RPCResult {
        await rpc("unblock_user", body: ["p_other_user_id": otherUserId])
    }

    @discardableResult
    func reportUser(otherUserId: String, reason: String, details: String) async -> RPCResult {
        await rpc("report_user", body: [
            "p_other_user_id": otherUserId,
            "p_reason": reason,
            "p_details": details
        ])
    }

    func fetchBlocks(myUserId: String) async -> [BlockRow] {
        let path = "blocks?blocker_id=eq.\(myUserId)&select=*&order=created_at.desc"
        return await get(path, as: [BlockRow].self) ?? []
    }

    // MARK: - Challenges

    @discardableResult
    func sendChallenge(opponentUsername: String, category: String) async -> RPCResult {
        await rpc("send_challenge", body: [
            "p_opponent_username": opponentUsername,
            "p_category": category
        ])
    }

    @discardableResult
    func respondChallenge(challengeId: String, accept: Bool) async -> RPCResult {
        await rpc("respond_challenge", body: [
            "p_challenge_id": challengeId,
            "p_accept": accept
        ])
    }

    @discardableResult
    func submitChallengeScore(challengeId: String, score: Double, photoURL: String) async -> RPCResult {
        await rpc("submit_challenge_score", body: [
            "p_challenge_id": challengeId,
            "p_score": score,
            "p_photo_url": photoURL
        ])
    }

    func fetchChallenges(myUserId: String) async -> [ChallengeRow] {
        let pathA = "challenges?challenger_id=eq.\(myUserId)&select=*&order=created_at.desc"
        let pathB = "challenges?opponent_id=eq.\(myUserId)&select=*&order=created_at.desc"
        async let asChallenger: [ChallengeRow]? = get(pathA, as: [ChallengeRow].self)
        async let asOpponent: [ChallengeRow]? = get(pathB, as: [ChallengeRow].self)
        let all = (await asChallenger ?? []) + (await asOpponent ?? [])
        return Array(Dictionary(grouping: all, by: { $0.id })
            .compactMap { $0.value.first }
            .sorted { $0.createdAt > $1.createdAt })
    }

    // MARK: - Notifications inbox

    func fetchNotifications(myUserId: String, limit: Int = 50) async -> [NotificationRow] {
        let path = "notifications?user_id=eq.\(myUserId)&select=*&order=created_at.desc&limit=\(limit)"
        return await get(path, as: [NotificationRow].self) ?? []
    }

    func unreadCount(myUserId: String) async -> Int {
        let path = "notifications?user_id=eq.\(myUserId)&read=eq.false&select=id"
        let rows: [IdRow] = await get(path, as: [IdRow].self) ?? []
        return rows.count
    }

    @discardableResult
    func markNotificationsRead(_ ids: [String]) async -> RPCResult {
        await rpc("mark_notifications_read", body: ["p_ids": ids])
    }

    // MARK: - Activity feed

    @discardableResult
    func postActivity(kind: String, payload: [String: Any]) async -> RPCResult {
        await rpc("post_activity", body: [
            "p_kind": kind,
            "p_payload": payload
        ])
    }

    /// Pull recent events from people the user can see (handled server-side by RLS).
    func fetchActivityFeed(limit: Int = 50) async -> [ActivityEventRow] {
        let path = "activity_events?select=*&order=created_at.desc&limit=\(limit)"
        return await get(path, as: [ActivityEventRow].self) ?? []
    }

    // MARK: - Group challenges

    @discardableResult
    func createGroupChallenge(
        title: String,
        description: String,
        metric: String,
        target: Double,
        endsAt: Date
    ) async -> RPCResult {
        let iso = ISO8601DateFormatter().string(from: endsAt)
        return await rpc("create_group_challenge", body: [
            "p_title": title,
            "p_description": description,
            "p_metric": metric,
            "p_target": target,
            "p_ends_at": iso
        ])
    }

    @discardableResult
    func inviteToGroupChallenge(challengeId: String, friendUsername: String) async -> RPCResult {
        await rpc("invite_to_group_challenge", body: [
            "p_challenge_id": challengeId,
            "p_friend_username": friendUsername
        ])
    }

    @discardableResult
    func updateGroupChallengeScore(challengeId: String, score: Double) async -> RPCResult {
        await rpc("update_group_challenge_score", body: [
            "p_challenge_id": challengeId,
            "p_score": score
        ])
    }

    func fetchGroupChallenges(myUserId: String) async -> [GroupChallengeRow] {
        // Membership table tells us which challenges the user is in.
        let memberPath = "group_challenge_members?user_id=eq.\(myUserId)&select=challenge_id"
        guard let memberRows: [ChallengeIdRow] = await get(memberPath, as: [ChallengeIdRow].self),
              !memberRows.isEmpty else {
            return []
        }
        let ids = memberRows.map { $0.challengeId }.joined(separator: ",")
        let path = "group_challenges?id=in.(\(ids))&select=*&order=ends_at.desc"
        return await get(path, as: [GroupChallengeRow].self) ?? []
    }

    func fetchGroupChallengeMembers(challengeId: String) async -> [GroupChallengeMemberRow] {
        let path = "group_challenge_members?challenge_id=eq.\(challengeId)&select=*&order=score.desc"
        return await get(path, as: [GroupChallengeMemberRow].self) ?? []
    }
}

// MARK: - RPC result

enum RPCResult {
    case success([String: Any])
    case softFailure(reason: String, raw: [String: Any])
    case failure(String)

    var ok: Bool { if case .success = self { return true }; return false }

    var failureReason: String? {
        switch self {
        case .softFailure(let reason, _): return reason
        case .failure(let msg): return msg
        case .success: return nil
        }
    }
}

// MARK: - Decoded row types

private struct UsernameAvailabilityRow: Decodable {
    let id: String
}

private struct IdRow: Decodable {
    let id: String
}

private struct ChallengeIdRow: Decodable {
    let challengeId: String
    enum CodingKeys: String, CodingKey { case challengeId = "challenge_id" }
}

struct SocialProfileSummary: Decodable, Identifiable, Hashable {
    let id: String
    let username: String
    let name: String?
    let avatarSystemName: String?
    /// Public URL of the friend's custom avatar (Supabase Storage). nil
    /// when they use an SF Symbol avatar — fall back to `avatarSystemName`.
    let profilePhotoURL: String?
    let tier: String?
    let points: Int?
    let totalWorkouts: Int?
    let currentStreak: Int?
    let latestScore: Double?
    let privacyMode: String?
    /// ISO8601 timestamp of the friend's last app foreground. Drives the
    /// online presence dot — fresh within 5 min = green.
    let lastSeenAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, tier, points
        case avatarSystemName = "avatar_system_name"
        case profilePhotoURL = "profile_photo_url"
        case totalWorkouts = "total_workouts"
        case currentStreak = "current_streak"
        case latestScore = "latest_score"
        case privacyMode = "privacy_mode"
        case lastSeenAt = "last_seen_at"
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "@\(username)"
    }

    /// True if `lastSeenAt` is within the past 5 minutes — i.e., the
    /// friend bumped their heartbeat in this presence window.
    var isOnline: Bool {
        guard let lastSeenAt,
              let date = ISO8601DateFormatter().date(from: lastSeenAt) else {
            return false
        }
        return Date().timeIntervalSince(date) < 300  // 5 min
    }
}

/// Richer profile fetched on-demand when opening a single friend's profile
/// sheet. Includes bio + the same stats as the leaderboard summary.
struct FriendProfileDetail: Decodable, Identifiable, Hashable {
    let id: String
    let username: String
    let name: String?
    let bio: String?
    let avatarSystemName: String?
    /// Public URL of friend's custom avatar — overrides avatarSystemName
    /// in the UI when present.
    let profilePhotoURL: String?
    let tier: String?
    let points: Int?
    let totalWorkouts: Int?
    let currentStreak: Int?
    let latestScore: Double?
    let privacyMode: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, bio, tier, points
        case avatarSystemName = "avatar_system_name"
        case profilePhotoURL  = "profile_photo_url"
        case totalWorkouts    = "total_workouts"
        case currentStreak    = "current_streak"
        case latestScore      = "latest_score"
        case privacyMode      = "privacy_mode"
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "@\(username)"
    }
}

struct FriendRequestRow: Decodable, Identifiable, Hashable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: String
    let createdAt: Date
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}

struct FriendshipRow: Decodable, Identifiable, Hashable {
    let userA: String
    let userB: String
    let createdAt: Date

    var id: String { "\(userA)-\(userB)" }

    enum CodingKeys: String, CodingKey {
        case userA = "user_a"
        case userB = "user_b"
        case createdAt = "created_at"
    }

    func otherUserId(forMe me: String) -> String {
        userA == me ? userB : userA
    }
}

struct BlockRow: Decodable, Identifiable, Hashable {
    let blockerId: String
    let blockedId: String
    let createdAt: Date

    var id: String { "\(blockerId)-\(blockedId)" }

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
        case createdAt = "created_at"
    }
}

struct ChallengeRow: Decodable, Identifiable, Hashable {
    let id: String
    let challengerId: String
    let opponentId: String
    let status: String
    let category: String
    let challengerScore: Double?
    let opponentScore: Double?
    let challengerPhotoURL: String?
    let opponentPhotoURL: String?
    let winnerUserId: String?
    let createdAt: Date
    let respondedAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, category
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
        case challengerScore = "challenger_score"
        case opponentScore = "opponent_score"
        case challengerPhotoURL = "challenger_photo_url"
        case opponentPhotoURL = "opponent_photo_url"
        case winnerUserId = "winner_user_id"
        case createdAt = "created_at"
        case respondedAt = "responded_at"
        case completedAt = "completed_at"
    }
}

struct NotificationRow: Decodable, Identifiable, Hashable {
    let id: String
    let userId: String
    let kind: String
    let payload: [String: SocialJSONValue]
    let read: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, payload, read
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct ActivityEventRow: Decodable, Identifiable, Hashable {
    let id: String
    let userId: String
    let kind: String
    let payload: [String: SocialJSONValue]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, payload
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct GroupChallengeRow: Decodable, Identifiable, Hashable {
    let id: String
    let creatorId: String
    let title: String
    let description: String
    let metric: String
    let target: Double
    let startsAt: Date
    let endsAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, metric, target
        case creatorId = "creator_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case createdAt = "created_at"
    }
}

struct GroupChallengeMemberRow: Decodable, Identifiable, Hashable {
    let challengeId: String
    let userId: String
    let score: Double
    let lastUpdated: Date

    var id: String { "\(challengeId)-\(userId)" }

    enum CodingKeys: String, CodingKey {
        case score
        case challengeId = "challenge_id"
        case userId = "user_id"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Loose JSON helper for notification/activity payloads

struct SocialJSONValue: Decodable, Hashable {
    let value: Any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode([String: SocialJSONValue].self) { value = v }
        else if let v = try? c.decode([SocialJSONValue].self) { value = v }
        else { value = NSNull() }
    }

    static func == (lhs: SocialJSONValue, rhs: SocialJSONValue) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
}
