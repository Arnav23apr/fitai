import SwiftUI
import Auth

#if canImport(Realtime)
import Realtime
#endif

/// Server-backed social view model. Replaces the previous local-only fake
/// (which appended "added" friends to UserDefaults and auto-accepted
/// challenges via Task.sleep). Every mutation now goes through SocialService
/// → SECURITY DEFINER RPC, and lists are pulled from Supabase.
@Observable
@MainActor
final class FriendViewModel {

    // MARK: - State

    /// Accepted friendships (the OTHER user, hydrated with profile data).
    var friends: [SocialProfileSummary] = []
    var incomingRequests: [PopulatedFriendRequest] = []
    var outgoingRequests: [PopulatedFriendRequest] = []
    var challenges: [PopulatedChallenge] = []
    var notifications: [NotificationRow] = []
    var unreadNotificationCount: Int = 0
    var blocks: [PopulatedBlock] = []

    var isRefreshing: Bool = false
    var lastError: String? = nil
    var successMessage: String? = nil

    /// Username search (still used in AddFriendSheet).
    var searchText: String = ""
    var isSearching: Bool = false
    var searchResult: SocialProfileSummary? = nil
    var searchError: String? = nil

    var showAddFriend: Bool = false
    var showRequestsInbox: Bool = false
    var showChallengeSetup: Bool = false
    var showNotificationsInbox: Bool = false
    var selectedFriend: SocialProfileSummary? = nil
    var challengeCategory: String = "physique"

    private let social = SocialService.shared
    private weak var appState: AppState?
    private var myUserId: String? { appState?.currentUserIdPublic }

    /// Notifications already surfaced as a banner this session — prevents
    /// the same row from firing twice when a refresh re-pulls it.
    private var bannerSeenNotifIds: Set<String> = []
    /// Cutoff: only fire banners for notifications newer than this. Set
    /// to "now" on the very first refresh so the user doesn't get spammed
    /// with backlog banners for every unread notification on cold launch.
    private var bannerCutoff: Date? = nil

    /// Active Realtime channel for the Compete tab. Lifecycle is owned by
    /// CompeteView via startRealtime / stopRealtime — we don't auto-start
    /// in `attach` because the channel should only run while the tab is
    /// visible (battery + connection-budget hygiene).
    ///
    /// Wrapped in canImport so the file compiles even when the Realtime
    /// SPM product isn't linked. start/stop become no-ops in that case.
    #if canImport(Realtime)
    private var realtimeChannel: RealtimeChannelV2?
    #endif
    private var realtimeListenerTasks: [Task<Void, Never>] = []

    /// Authoritative current-user id sourced from the live Supabase auth
    /// session. Falls back to `appState.currentUserIdPublic` if no session,
    /// which avoids any drift between the cached id and the actual JWT
    /// subject used for RLS checks.
    private func resolveMyUserId() async -> String? {
        if let session = await SupabaseAuthService.shared.currentSession() {
            return session.user.id.uuidString.lowercased()
        }
        return appState?.currentUserIdPublic
    }

    // MARK: - Init

    init() {}

    func attach(_ appState: AppState) {
        self.appState = appState
    }

    // MARK: - Computed slices

    var activeChallenges: [PopulatedChallenge] {
        challenges.filter { ["pending", "accepted", "in_progress"].contains($0.row.status) }
            .sorted { $0.row.createdAt > $1.row.createdAt }
    }

    var completedChallenges: [PopulatedChallenge] {
        challenges.filter { $0.row.status == "completed" }
            .sorted { ($0.row.completedAt ?? $0.row.createdAt) > ($1.row.completedAt ?? $1.row.createdAt) }
    }

    var pendingIncomingChallenges: [PopulatedChallenge] {
        guard let me = myUserId else { return [] }
        return challenges.filter { $0.row.opponentId == me && $0.row.status == "pending" }
    }

    // MARK: - Head-to-head + turn state (UI helpers)

    /// Lifetime W-L record vs a specific friend, counted from completed
    /// challenges only. Draws (winner_user_id == nil) are dropped from both
    /// counts since the UI only shows W-L.
    func headToHead(with friend: SocialProfileSummary) -> (wins: Int, losses: Int) {
        guard let me = myUserId else { return (0, 0) }
        let theirs = friend.id
        var wins = 0
        var losses = 0
        for ch in challenges where ch.row.status == "completed" {
            let isPairMatch = (ch.row.challengerId == me && ch.row.opponentId == theirs)
                           || (ch.row.challengerId == theirs && ch.row.opponentId == me)
            guard isPairMatch, let winner = ch.row.winnerUserId else { continue }
            if winner == me { wins += 1 } else if winner == theirs { losses += 1 }
        }
        return (wins, losses)
    }

    /// Whose move it is on an active challenge. Used by the challenge row to
    /// show "Your turn" vs "Waiting for @opp" instead of generic "In progress".
    enum ChallengeTurn { case mine, theirs, both }
    func turn(for ch: PopulatedChallenge) -> ChallengeTurn? {
        guard ["accepted", "in_progress"].contains(ch.row.status) else { return nil }
        let myScore = ch.iAmChallenger ? ch.row.challengerScore : ch.row.opponentScore
        let theirScore = ch.iAmChallenger ? ch.row.opponentScore : ch.row.challengerScore
        if myScore == nil && theirScore == nil { return .both }
        if myScore == nil { return .mine }
        if theirScore == nil { return .theirs }
        return .both
    }

    // MARK: - Hype

    /// Friend IDs that the user has just successfully hyped — used by the row
    /// to swap the button into a confirmed/cooldown state for the rest of the
    /// session. Server enforces the real 24h throttle; this is purely visual.
    var recentlyHypedFriendIds: Set<String> = []
    /// Friend IDs whose hype request is currently in flight. Disables the
    /// button + shows a spinner so the user can't tap-spam.
    var hypingFriendIds: Set<String> = []

    func sendHype(to friend: SocialProfileSummary) async {
        guard !hypingFriendIds.contains(friend.id) else { return }
        hypingFriendIds.insert(friend.id)
        defer { hypingFriendIds.remove(friend.id) }
        let result = await social.sendHype(toUserId: friend.id)
        switch result {
        case .success:
            recentlyHypedFriendIds.insert(friend.id)
            successMessage = "Hype sent to @\(friend.username)"
        case .softFailure(let reason, _):
            if reason == "throttled" {
                recentlyHypedFriendIds.insert(friend.id)
                successMessage = "Already hyped @\(friend.username) today"
            } else {
                lastError = friendlyReason(reason)
            }
        case .failure(let msg):
            lastError = msg
        }
        clearTransientMessagesSoon()
    }

    // MARK: - Refresh

    /// Pulls every social entity from Supabase in parallel and hydrates
    /// referenced user profiles in a single batch lookup.
    func refresh() async {
        guard let me = await resolveMyUserId() else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let friendshipsT = social.fetchFriendships(myUserId: me)
        async let incomingT = social.fetchIncomingRequests(myUserId: me)
        async let outgoingT = social.fetchOutgoingRequests(myUserId: me)
        async let challengesT = social.fetchChallenges(myUserId: me)
        async let notificationsT = social.fetchNotifications(myUserId: me)
        async let blocksT = social.fetchBlocks(myUserId: me)

        let friendships = await friendshipsT
        let incoming = await incomingT
        let outgoing = await outgoingT
        let challengeRows = await challengesT
        let notifs = await notificationsT
        let blockRows = await blocksT

        // Collect every user id we need profile data for.
        var ids: Set<String> = []
        for f in friendships { ids.insert(f.otherUserId(forMe: me)) }
        for r in incoming { ids.insert(r.fromUserId) }
        for r in outgoing { ids.insert(r.toUserId) }
        for c in challengeRows { ids.insert(c.challengerId); ids.insert(c.opponentId) }
        for b in blockRows { ids.insert(b.blockedId) }

        let profiles = await social.fetchProfilesByIds(Array(ids))

        // Materialize hydrated views.
        friends = friendships.compactMap { profiles[$0.otherUserId(forMe: me)] }

        incomingRequests = incoming.compactMap {
            guard let p = profiles[$0.fromUserId] else { return nil }
            return PopulatedFriendRequest(row: $0, otherUser: p)
        }
        outgoingRequests = outgoing.compactMap {
            guard let p = profiles[$0.toUserId] else { return nil }
            return PopulatedFriendRequest(row: $0, otherUser: p)
        }

        challenges = challengeRows.compactMap {
            let isMeChallenger = $0.challengerId == me
            let otherId = isMeChallenger ? $0.opponentId : $0.challengerId
            guard let other = profiles[otherId] else { return nil }
            return PopulatedChallenge(row: $0, otherUser: other, iAmChallenger: isMeChallenger)
        }

        blocks = blockRows.compactMap {
            guard let p = profiles[$0.blockedId] else { return nil }
            return PopulatedBlock(row: $0, blockedUser: p)
        }

        notifications = notifs
        unreadNotificationCount = notifs.filter { !$0.read }.count

        surfaceNewNotificationBanners(notifs, profiles: profiles)
    }

    /// Drops a toast banner via `AppState.showBanner` for any notification
    /// row that arrived since the last refresh (or since app launch on the
    /// first call). On the very first refresh of a session we set the
    /// cutoff to "now" and fire nothing — that way the user doesn't get
    /// spammed with backlog banners for old unread items.
    private func surfaceNewNotificationBanners(
        _ notifs: [NotificationRow],
        profiles: [String: SocialProfileSummary]
    ) {
        guard let appState else { return }
        // First-ever refresh of this session — set cutoff and skip.
        guard let cutoff = bannerCutoff else {
            bannerCutoff = Date()
            return
        }

        let newRows = notifs.filter { n in
            n.createdAt > cutoff && !bannerSeenNotifIds.contains(n.id)
        }
        guard !newRows.isEmpty else { return }

        // Advance the cutoff so we don't re-evaluate these rows next time.
        let newestSeen = newRows.map(\.createdAt).max() ?? cutoff
        bannerCutoff = max(cutoff, newestSeen)

        // Fire one banner per kind we know how to render. Limit to one
        // per refresh so a burst of notifications doesn't queue 5 toasts.
        for row in newRows.prefix(1) {
            bannerSeenNotifIds.insert(row.id)
            if let banner = bannerForNotification(row, profiles: profiles) {
                appState.showBanner(banner)
            }
        }
    }

    private func bannerForNotification(
        _ row: NotificationRow,
        profiles: [String: SocialProfileSummary]
    ) -> InAppBanner? {
        switch row.kind {
        case "friend_request_received":
            let fromUserId = row.payload["from_user_id"]?.stringValue
            let senderName: String = {
                if let id = fromUserId, let p = profiles[id] { return p.displayName }
                return "Someone"
            }()
            return InAppBanner(
                title: "New friend request",
                subtitle: "\(senderName) wants to connect",
                icon: "person.crop.circle.badge.plus",
                iconTint: .blue
            )
        case "friend_request_accepted":
            let fromUserId = row.payload["from_user_id"]?.stringValue
            let senderName: String = {
                if let id = fromUserId, let p = profiles[id] { return p.displayName }
                return "Someone"
            }()
            return InAppBanner(
                title: "Friend request accepted",
                subtitle: "You and \(senderName) are now friends",
                icon: "checkmark.circle.fill",
                iconTint: .green
            )
        case "challenge_received", "challenge_invite":
            return InAppBanner(
                title: "New challenge",
                subtitle: "Someone challenged you",
                icon: "trophy.fill",
                iconTint: .orange
            )
        default:
            return nil
        }
    }

    /// Lightweight refresh that only re-pulls the friend profile rows
    /// (so `lastSeenAt` and avatar URL update). Used by the realtime
    /// presence subscription so a friend toggling online doesn't trigger
    /// a full refetch of friendships + requests + challenges + notifs.
    func refreshFriendsPresence() async {
        guard !friends.isEmpty else { return }
        let ids = friends.map(\.id)
        let profiles = await social.fetchProfilesByIds(ids)
        // Preserve current ordering; only update fields that changed.
        friends = friends.compactMap { profiles[$0.id] ?? $0 }
    }

    // MARK: - Realtime

    /// Open a Realtime channel that re-runs `refresh()` whenever a row in
    /// `friend_requests`, `friendships`, `challenges`, or `notifications`
    /// changes. RLS still applies on broadcast so we only get rows we
    /// could have selected via REST anyway.
    ///
    /// Idempotent — calling twice closes the prior channel first. Called
    /// from `CompeteView.task` on appear; `stopRealtime` from `.onDisappear`.
    func startRealtime() async {
        await stopRealtime()
        #if canImport(Realtime)
        guard let me = await resolveMyUserId() else { return }

        let channel = RealtimeService.shared.client.channel("compete:\(me)")

        let onChange: @Sendable (AnyAction) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }

        _ = channel.onPostgresChange(AnyAction.self,
                                     schema: "public",
                                     table: "friend_requests",
                                     callback: onChange)
        _ = channel.onPostgresChange(AnyAction.self,
                                     schema: "public",
                                     table: "challenges",
                                     callback: onChange)
        _ = channel.onPostgresChange(AnyAction.self,
                                     schema: "public",
                                     table: "notifications",
                                     filter: "user_id=eq.\(me)",
                                     callback: onChange)
        _ = channel.onPostgresChange(AnyAction.self,
                                     schema: "public",
                                     table: "friendships",
                                     callback: onChange)

        // Realtime presence: any UPDATE to `user_profiles` (most commonly
        // a `last_seen_at` heartbeat from a friend) triggers a lightweight
        // re-pull of just the friend profile rows so the green online dot
        // updates live without a full refresh. RLS still gates broadcast,
        // so we only get notified for rows we could SELECT — i.e. our own
        // friends, not the whole user base.
        let onPresenceChange: @Sendable (AnyAction) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshFriendsPresence()
            }
        }
        _ = channel.onPostgresChange(AnyAction.self,
                                     schema: "public",
                                     table: "user_profiles",
                                     callback: onPresenceChange)

        await channel.subscribe()
        realtimeChannel = channel
        realtimeListenerTasks = []
        #endif
    }

    /// Tear down the channel. Called on view disappear / sign-out.
    /// No-op when Realtime SPM isn't linked — the canImport guards make
    /// realtimeChannel non-existent in that build.
    func stopRealtime() async {
        for task in realtimeListenerTasks { task.cancel() }
        realtimeListenerTasks = []
        #if canImport(Realtime)
        if let channel = realtimeChannel {
            await channel.unsubscribe()
        }
        realtimeChannel = nil
        #endif
    }

    // MARK: - Username search

    func searchUser() async {
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        searchError = nil
        searchResult = nil
        isSearching = true
        defer { isSearching = false }

        // Use LeaderboardService.searchUser then hydrate to SocialProfileSummary.
        if let leaderboard = await LeaderboardService.shared.searchUser(username: normalized) {
            // Block-list / self check.
            if normalized == (appState?.profile.username.lowercased() ?? "") {
                searchError = "That's you — try someone else."
                return
            }
            if friends.contains(where: { $0.username.lowercased() == normalized }) {
                searchError = "Already friends with @\(normalized)"
                return
            }
            if outgoingRequests.contains(where: { $0.otherUser.username.lowercased() == normalized }) {
                searchError = "You already sent @\(normalized) a request — check the Requests tab."
                return
            }
            if incomingRequests.contains(where: { $0.otherUser.username.lowercased() == normalized }) {
                searchError = "@\(normalized) sent you a request — check the Requests tab."
                return
            }
            searchResult = SocialProfileSummary(
                id: leaderboard.id,
                username: leaderboard.username,
                name: leaderboard.displayName,
                avatarSystemName: nil,
                profilePhotoURL: nil,
                tier: leaderboard.tier,
                points: leaderboard.points,
                totalWorkouts: leaderboard.totalWorkouts,
                currentStreak: leaderboard.streak,
                latestScore: nil,
                privacyMode: nil,
                lastSeenAt: nil,
                isPremium: nil
            )
        } else {
            searchError = "User @\(normalized) not found."
        }
    }

    // MARK: - Friend requests

    func sendFriendRequest(toUsername: String) async {
        var result = await social.sendFriendRequest(toUsername: toUsername)

        // If the server says we don't have a username but we DO locally, the
        // identity row never made it up. Push it now and retry once. This
        // covers users whose accounts predate the username picker, plus any
        // setIdentity calls that silently failed in the past.
        if case .softFailure(let reason, _) = result, reason == "username_required",
           let me = appState?.currentUserIdPublic,
           let local = appState?.profile,
           !local.username.isEmpty {
            await SupabaseSyncService.shared.setIdentity(
                userId: me,
                name: local.name,
                username: local.username,
                email: local.email
            )
            result = await social.sendFriendRequest(toUsername: toUsername)
        }

        switch result {
        case .success:
            successMessage = "Request sent to @\(toUsername)"
            await refresh()
        case .softFailure(let reason, _):
            lastError = friendlyReason(reason)
        case .failure(let msg):
            lastError = msg
        }
        clearTransientMessagesSoon()
    }

    func acceptRequest(_ req: PopulatedFriendRequest) async {
        let result = await social.respondFriendRequest(requestId: req.row.id, accept: true)
        if result.ok {
            successMessage = "You and @\(req.otherUser.username) are now friends"
            await refresh()
        } else {
            lastError = friendlyReason(result.failureReason ?? "unknown")
        }
        clearTransientMessagesSoon()
    }

    func declineRequest(_ req: PopulatedFriendRequest) async {
        // Optimistic UI: drop the row immediately so the inbox empties.
        incomingRequests.removeAll { $0.id == req.id }
        _ = await social.respondFriendRequest(requestId: req.row.id, accept: false)
        await refresh()
    }

    func cancelOutgoingRequest(_ req: PopulatedFriendRequest) async {
        outgoingRequests.removeAll { $0.id == req.id }
        _ = await social.cancelFriendRequest(requestId: req.row.id)
        await refresh()
    }

    func removeFriend(_ friend: SocialProfileSummary) async {
        // Optimistic UI: drop them from the local list immediately so the row
        // animates out without waiting for the server round-trip + refresh.
        friends.removeAll { $0.id == friend.id }
        _ = await social.removeFriendship(otherUserId: friend.id)
        await refresh()
    }

    // MARK: - Challenges

    /// True when there's already a non-terminal challenge between us and this
    /// opponent. Used to gate a second "send challenge" tap until the first
    /// one resolves — research-driven dedupe so users don't spam the same
    /// friend with overlapping battles.
    func hasOpenChallenge(with opponent: SocialProfileSummary) -> Bool {
        challenges.contains {
            $0.otherUser.id == opponent.id &&
            $0.row.status != "completed" &&
            $0.row.status != "declined" &&
            $0.row.status != "expired"
        }
    }

    func sendChallenge(opponent: SocialProfileSummary, category: String) async {
        if hasOpenChallenge(with: opponent) {
            lastError = "You already have an open challenge with @\(opponent.username). Finish that one first."
            clearTransientMessagesSoon()
            return
        }

        var result = await social.sendChallenge(opponentUsername: opponent.username, category: category)

        // Same `username_required` recovery as sendFriendRequest — push local
        // identity then retry once.
        if !result.ok, result.failureReason == "username_required",
           let me = appState?.currentUserIdPublic,
           let local = appState?.profile,
           !local.username.isEmpty {
            await SupabaseSyncService.shared.setIdentity(
                userId: me,
                name: local.name,
                username: local.username,
                email: local.email
            )
            result = await social.sendChallenge(opponentUsername: opponent.username, category: category)
        }

        if result.ok {
            successMessage = "Challenge sent to @\(opponent.username)"
            await refresh()
        } else {
            lastError = friendlyReason(result.failureReason ?? "unknown")
        }
        clearTransientMessagesSoon()
    }

    func acceptChallenge(_ ch: PopulatedChallenge) async {
        _ = await social.respondChallenge(challengeId: ch.row.id, accept: true)
        await refresh()
    }

    func declineChallenge(_ ch: PopulatedChallenge) async {
        _ = await social.respondChallenge(challengeId: ch.row.id, accept: false)
        await refresh()
    }

    func submitChallengeScore(
        _ ch: PopulatedChallenge,
        score: Double,
        photoURL: String,
        analysis: ChallengeAnalysis? = nil
    ) async {
        _ = await social.submitChallengeScore(
            challengeId: ch.row.id,
            score: score,
            photoURL: photoURL,
            analysis: analysis
        )
        await refresh()

        // If after refresh the challenge is completed and we won, post to activity feed.
        if let me = appState?.currentUserIdPublic,
           let updated = challenges.first(where: { $0.row.id == ch.row.id }),
           updated.row.status == "completed",
           updated.row.winnerUserId == me {
            await social.postActivity(
                kind: "challenge_won",
                payload: [
                    "challenge_id": ch.row.id,
                    "category": ch.row.category,
                    "opponent_username": ch.otherUser.username
                ]
            )
        }
    }

    // MARK: - Blocks + reports

    func block(_ user: SocialProfileSummary) async {
        // Optimistic UI: blocking implicitly drops friendship + cancels any
        // pending request, so remove from every local list before the server
        // round-trip. Server-side `block_user` does the same atomically.
        friends.removeAll { $0.id == user.id }
        incomingRequests.removeAll { $0.otherUser.id == user.id }
        outgoingRequests.removeAll { $0.otherUser.id == user.id }
        successMessage = "Blocked @\(user.username)"
        _ = await social.blockUser(otherUserId: user.id)
        await refresh()
        clearTransientMessagesSoon()
    }

    func unblock(_ user: SocialProfileSummary) async {
        blocks.removeAll { $0.blockedUser.id == user.id }
        _ = await social.unblockUser(otherUserId: user.id)
        await refresh()
    }

    func report(_ user: SocialProfileSummary, reason: String, details: String) async {
        let r = await social.reportUser(otherUserId: user.id, reason: reason, details: details)
        if r.ok {
            successMessage = "Report submitted. Thanks — we'll review it."
        } else {
            lastError = friendlyReason(r.failureReason ?? "unknown")
        }
        clearTransientMessagesSoon()
    }

    // MARK: - Notifications

    func markAllNotificationsRead() async {
        let unread = notifications.filter { !$0.read }.map(\.id)
        guard !unread.isEmpty else { return }
        _ = await social.markNotificationsRead(unread)
        await refresh()
    }

    // MARK: - Helpers

    private func clearTransientMessagesSoon() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            successMessage = nil
            lastError = nil
        }
    }

    private func friendlyReason(_ raw: String) -> String {
        switch raw {
        case "user_not_found":      return "User not found."
        case "self_target":         return "That's you."
        case "cannot_friend_self":  return "That's you."
        case "cannot_challenge_self": return "That's you."
        case "blocked":             return "Can't reach this user."
        case "already_friends":     return "Already friends."
        case "already_pending":     return "There's already a pending request between you."
        case "not_friends":         return "You can only challenge friends."
        case "not_recipient":       return "That request isn't yours to respond to."
        case "not_pending":         return "Request is no longer pending."
        case "invalid_state":       return "This challenge can't be modified right now."
        case "unauthenticated":     return "Please sign in again."
        case "rate_limited":        return "You're sending requests too fast. Try again in an hour."
        case "username_not_allowed": return "That username isn't allowed. Pick another."
        case "username_required":   return "Set a username first — Profile → Edit profile."
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Hydrated row types

struct PopulatedFriendRequest: Identifiable, Hashable {
    let row: FriendRequestRow
    let otherUser: SocialProfileSummary
    var id: String { row.id }
}

struct PopulatedChallenge: Identifiable, Hashable {
    let row: ChallengeRow
    let otherUser: SocialProfileSummary
    let iAmChallenger: Bool
    var id: String { row.id }
}

struct PopulatedBlock: Identifiable, Hashable {
    let row: BlockRow
    let blockedUser: SocialProfileSummary
    var id: String { row.id }
}
