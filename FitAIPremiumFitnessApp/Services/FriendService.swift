import Foundation

class FriendService {
    static let shared = FriendService()

    private let friendsKey = "savedFriends"
    private let requestsKey = "savedFriendRequests"
    private let challengesKey = "savedChallenges"
    private let usernameKey = "userUsername"

    func saveUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: usernameKey)
    }

    func getUsername() -> String? {
        UserDefaults.standard.string(forKey: usernameKey)
    }

    func saveFriends(_ friends: [Friend]) {
        if let data = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(data, forKey: friendsKey)
        }
    }

    func loadFriends() -> [Friend] {
        guard let data = UserDefaults.standard.data(forKey: friendsKey),
              let friends = try? JSONDecoder().decode([Friend].self, from: data) else {
            return []
        }
        return friends
    }

    func saveRequests(_ requests: [FriendRequest]) {
        if let data = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(data, forKey: requestsKey)
        }
    }

    func loadRequests() -> [FriendRequest] {
        guard let data = UserDefaults.standard.data(forKey: requestsKey),
              let requests = try? JSONDecoder().decode([FriendRequest].self, from: data) else {
            return []
        }
        return requests
    }

    func saveChallenges(_ challenges: [Challenge1v1]) {
        if let data = try? JSONEncoder().encode(challenges) {
            UserDefaults.standard.set(data, forKey: challengesKey)
        }
    }

    func loadChallenges() -> [Challenge1v1] {
        guard let data = UserDefaults.standard.data(forKey: challengesKey),
              let challenges = try? JSONDecoder().decode([Challenge1v1].self, from: data) else {
            return []
        }
        return challenges
    }

    func generateSampleFriends() -> [Friend] {
        [
            Friend(username: "iron_mike", displayName: "Mike T.", avatarEmoji: "🏋️", tier: "Gold", points: 3200, totalWorkouts: 45, currentStreak: 12),
            Friend(username: "sarah_lifts", displayName: "Sarah K.", avatarEmoji: "💪", tier: "Platinum", points: 7500, totalWorkouts: 89, currentStreak: 21),
            Friend(username: "gym_jordan", displayName: "Jordan R.", avatarEmoji: "🔥", tier: "Silver", points: 1200, totalWorkouts: 22, currentStreak: 5),
        ]
    }
}
