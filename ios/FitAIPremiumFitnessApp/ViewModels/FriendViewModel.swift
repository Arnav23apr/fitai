import SwiftUI

@Observable
class FriendViewModel {
    var friends: [Friend] = []
    var pendingRequests: [FriendRequest] = []
    var challenges: [Challenge1v1] = []
    var username: String = ""
    var searchText: String = ""
    var isSearching: Bool = false
    var searchResult: Friend? = nil
    var searchError: String? = nil
    var showAddFriend: Bool = false
    var showChallengeSetup: Bool = false
    var selectedFriend: Friend? = nil
    var challengeCategory: String = "Physique Battle"
    var successMessage: String? = nil

    private let service = FriendService.shared

    init() {
        friends = service.loadFriends()
        pendingRequests = service.loadRequests()
        challenges = service.loadChallenges()
        username = service.getUsername() ?? ""
    }

    var activeChallenges: [Challenge1v1] {
        challenges.filter { $0.status == .pending || $0.status == .accepted || $0.status == .inProgress }
            .sorted { $0.sentDate > $1.sentDate }
    }

    var completedChallenges: [Challenge1v1] {
        challenges.filter { $0.status == .completed }
            .sorted { ($0.completedDate ?? $0.sentDate) > ($1.completedDate ?? $1.sentDate) }
    }

    var incomingRequests: [FriendRequest] {
        pendingRequests.filter { $0.status == .pending && $0.toUsername == username }
    }

    func setUsername(_ name: String) {
        username = name
        service.saveUsername(name)
    }

    func searchUser() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchError = nil
        searchResult = nil

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        if query == username.lowercased() {
            searchError = "That's you! Try someone else."
            isSearching = false
            return
        }

        if friends.contains(where: { $0.username.lowercased() == query }) {
            searchError = "Already friends with @\(query)"
            isSearching = false
            return
        }

        Task {
            let profile = await LeaderboardService.shared.searchUser(username: query)
            if let profile {
                searchResult = Friend(
                    username: profile.username,
                    displayName: profile.displayName,
                    avatarEmoji: tierEmoji(profile.tier),
                    tier: profile.tier,
                    points: profile.points,
                    totalWorkouts: profile.totalWorkouts,
                    currentStreak: profile.streak
                )
            } else {
                searchError = "User @\(query) not found. They need to sign up for FitAI first."
            }
            isSearching = false
        }
    }

    func sendFriendRequest(to friend: Friend) {
        let newFriend = Friend(
            id: friend.id,
            username: friend.username,
            displayName: friend.displayName,
            avatarEmoji: friend.avatarEmoji,
            tier: friend.tier,
            points: friend.points,
            totalWorkouts: friend.totalWorkouts,
            currentStreak: friend.currentStreak
        )
        friends.append(newFriend)
        service.saveFriends(friends)
        searchResult = nil
        searchText = ""
        successMessage = "Added @\(friend.username) as a friend!"

        Task {
            try? await Task.sleep(for: .seconds(2))
            successMessage = nil
        }
    }

    func removeFriend(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        service.saveFriends(friends)
    }

    func sendChallenge(to friend: Friend, category: String = "Physique Battle") {
        let challenge = Challenge1v1(
            challengerUsername: username,
            challengerName: "You",
            opponentUsername: friend.username,
            opponentName: friend.displayName,
            category: category
        )
        challenges.append(challenge)
        service.saveChallenges(challenges)
        successMessage = "Challenge sent to @\(friend.username)!"

        Task {
            try? await Task.sleep(for: .seconds(1))
            var updated = challenges
            if let idx = updated.firstIndex(where: { $0.id == challenge.id }) {
                updated[idx].status = .accepted
                challenges = updated
                service.saveChallenges(challenges)
            }
        }
    }

    func declineChallenge(_ challenge: Challenge1v1) {
        if let idx = challenges.firstIndex(where: { $0.id == challenge.id }) {
            challenges[idx].status = .declined
            service.saveChallenges(challenges)
        }
    }

    func completeChallenge(_ challenge: Challenge1v1, yourScore: Double, theirScore: Double) {
        if let idx = challenges.firstIndex(where: { $0.id == challenge.id }) {
            challenges[idx].status = .completed
            challenges[idx].completedDate = Date()
            challenges[idx].challengerScore = yourScore
            challenges[idx].opponentScore = theirScore
            challenges[idx].winnerUsername = yourScore >= theirScore ? challenges[idx].challengerUsername : challenges[idx].opponentUsername
            service.saveChallenges(challenges)
        }
    }

    func loadSampleData() {}

    private func tierEmoji(_ tier: String) -> String {
        switch tier.lowercased() {
        case "diamond": return "💎"
        case "platinum": return "🏆"
        case "gold": return "🥇"
        case "silver": return "🥈"
        default: return "🥉"
        }
    }
}
