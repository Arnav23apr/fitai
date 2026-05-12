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

    /// POST to an RPC and decode its `returns table` array response into
    /// the given type. Same auth + error handling as `get`, but the body
    /// goes JSON-serialized in the request instead of as URL query
    /// parameters. Used by the social-profile RPCs (migration 020) that
    /// bypass `user_profiles` RLS so the client can see strangers'
    /// public-display fields (sender of an incoming friend request,
    /// opponent in a challenge, etc).
    private func rpcDecode<T: Decodable>(_ name: String, body: [String: Any], as type: T.Type) async -> T? {
        guard let url = URL(string: "\(baseURL)/rpc/\(name)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
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
    /// Returns true if the username is free OR currently belongs to
    /// `currentUserId`. Routes through `is_username_taken` RPC (migration
    /// 020) because RLS on `user_profiles` would otherwise hide rows
    /// belonging to other users, making every taken username look free
    /// to the client until the unique-index violated on insert.
    func isUsernameAvailable(_ username: String, currentUserId: String?) async -> Bool? {
        let normalized = username
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 3 else { return nil }
        // RPC returns the owning user's UUID, or null if free. RPCs
        // returning a single scalar use a one-element array shape via
        // PostgREST, so we decode as [String?].
        let ownerArr: [String?]? = await rpcDecode(
            "is_username_taken",
            body: ["p_username": normalized],
            as: [String?].self
        )
        guard let arr = ownerArr else { return nil }
        guard let owner = arr.first.flatMap({ $0 }) else { return true }
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

    /// Lookup user profiles for a list of ids. Routes through the
    /// `get_social_profiles` RPC (migration 020) instead of a direct
    /// PostgREST query, because the only SELECT policy on `user_profiles`
    /// is `auth.uid() = id` — i.e. you can only read your own row. The
    /// RPC is SECURITY DEFINER and returns only the safe social-display
    /// fields, so strangers' profiles surface for sender-of-incoming-
    /// request, opponent-in-challenge, etc.
    func fetchProfilesByIds(_ ids: [String]) async -> [String: SocialProfileSummary] {
        guard !ids.isEmpty else { return [:] }
        let rows: [SocialProfileSummary] = await rpcDecode(
            "get_social_profiles",
            body: ["p_ids": ids],
            as: [SocialProfileSummary].self
        ) ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    /// Fetch a single friend's full profile (includes bio and richer fields
    /// not exposed by the leaderboard summary). Used by FriendProfileSheet.
    /// Routes through `get_social_profile_detail` RPC for the same RLS
    /// reasons as `fetchProfilesByIds`.
    func fetchProfileDetail(userId: String) async -> FriendProfileDetail? {
        let rows: [FriendProfileDetail] = await rpcDecode(
            "get_social_profile_detail",
            body: ["p_user_id": userId],
            as: [FriendProfileDetail].self
        ) ?? []
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
    func submitChallengeScore(
        challengeId: String,
        score: Double,
        photoURL: String,
        analysis: ChallengeAnalysis? = nil
    ) async -> RPCResult {
        var body: [String: Any] = [
            "p_challenge_id": challengeId,
            "p_score": score,
            "p_photo_url": photoURL
        ]
        if let analysis {
            body["p_analysis"] = analysis.toJSON()
        }
        return await rpc("submit_challenge_score", body: body)
    }

    /// Persists the AI verdict on a completed challenge. Idempotent
    /// server-side (first writer wins), so safe to call from both clients
    /// when each independently realizes the challenge transitioned to
    /// `completed`.
    @discardableResult
    func setChallengeVerdict(challengeId: String, verdict: String) async -> RPCResult {
        await rpc("set_challenge_verdict", body: [
            "p_challenge_id": challengeId,
            "p_verdict": verdict
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

    // MARK: - Friend hype

    /// Fire-and-forget "hype" push to a friend. Server enforces friendship +
    /// a 24h per-pair throttle, so callers don't need to debounce locally.
    /// Returns `.softFailure(reason: "throttled")` if the friend was already
    /// hyped in the last 24h.
    @discardableResult
    func sendHype(toUserId: String) async -> RPCResult {
        await rpc("send_hype", body: ["p_target_user_id": toUserId])
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
    /// True when the friend has an active Fit AI Pro entitlement. Drives
    /// the crown icon next to their name. Optional in the decoder so old
    /// rows from a pre-migration server keep working.
    let isPremium: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, name, tier, points
        case avatarSystemName = "avatar_system_name"
        case profilePhotoURL = "profile_photo_url"
        case totalWorkouts = "total_workouts"
        case currentStreak = "current_streak"
        case latestScore = "latest_score"
        case privacyMode = "privacy_mode"
        case lastSeenAt = "last_seen_at"
        case isPremium = "is_premium"
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
    /// True when the friend has an active Fit AI Pro entitlement. Drives
    /// the crown icon next to their name on the profile sheet.
    let isPremium: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, name, bio, tier, points
        case avatarSystemName = "avatar_system_name"
        case profilePhotoURL  = "profile_photo_url"
        case totalWorkouts    = "total_workouts"
        case currentStreak    = "current_streak"
        case latestScore      = "latest_score"
        case privacyMode      = "privacy_mode"
        case isPremium        = "is_premium"
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
    /// Full AI breakdown per side, written via `submit_challenge_score`'s
    /// new p_analysis param (migration 021). Both nullable so pre-021
    /// challenges still decode. When both are non-nil the iOS client can
    /// reconstruct a `PhysiqueBattle` and render `BattleResultView` —
    /// matching the local 1v1 result UI exactly. When either is nil the
    /// view falls back to the legacy minimal result card.
    let challengerAnalysis: ChallengeAnalysis?
    let opponentAnalysis: ChallengeAnalysis?
    /// AI verdict text, set once by whichever side submits last (via
    /// `set_challenge_verdict`). Idempotent server-side, so concurrent
    /// "both clients submit and try to write" doesn't double-write.
    let verdict: String?

    enum CodingKeys: String, CodingKey {
        case id, status, category, verdict
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
        case challengerAnalysis = "challenger_analysis"
        case opponentAnalysis = "opponent_analysis"
    }
}

/// Full per-side AI breakdown persisted on `challenges.challenger_analysis`
/// and `challenges.opponent_analysis` (migration 021). Mirrors
/// `AnalysisResult` from `BattleViewModel` but Codable so it round-trips
/// through Supabase as JSONB.
struct ChallengeAnalysis: Codable, Hashable {
    let overallScore: Double
    let muscleScores: CodableMuscleScores
    let potentialRating: Double
    let visibleMuscleGroups: [String]
    let strongPoints: [String]
    let weakPoints: [String]

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case muscleScores = "muscle_scores"
        case potentialRating = "potential_rating"
        case visibleMuscleGroups = "visible_muscle_groups"
        case strongPoints = "strong_points"
        case weakPoints = "weak_points"
    }

    /// Convert to the dictionary form `submit_challenge_score` expects
    /// in `p_analysis`. Snake-case keys match the JSONB column shape so
    /// the round-trip through Supabase is symmetric.
    func toJSON() -> [String: Any] {
        return [
            "overall_score": overallScore,
            "muscle_scores": [
                "chest": muscleScores.chest,
                "shoulders": muscleScores.shoulders,
                "back": muscleScores.back,
                "arms": muscleScores.arms,
                "legs": muscleScores.legs,
                "core": muscleScores.core,
                "glutes": muscleScores.glutes ?? 0,
            ],
            "potential_rating": potentialRating,
            "visible_muscle_groups": visibleMuscleGroups,
            "strong_points": strongPoints,
            "weak_points": weakPoints,
        ]
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
