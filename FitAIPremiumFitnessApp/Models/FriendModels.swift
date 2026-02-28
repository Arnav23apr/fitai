import Foundation

nonisolated enum FriendRequestStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}

nonisolated enum ChallengeStatus: String, Codable, Sendable {
    case pending
    case accepted
    case inProgress
    case completed
    case declined
    case expired
}

nonisolated struct Friend: Codable, Identifiable, Sendable {
    let id: String
    var username: String
    var displayName: String
    var avatarEmoji: String
    var tier: String
    var points: Int
    var totalWorkouts: Int
    var currentStreak: Int
    var addedDate: Date

    init(id: String = UUID().uuidString, username: String, displayName: String, avatarEmoji: String = "💪", tier: String = "Bronze", points: Int = 0, totalWorkouts: Int = 0, currentStreak: Int = 0, addedDate: Date = Date()) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.tier = tier
        self.points = points
        self.totalWorkouts = totalWorkouts
        self.currentStreak = currentStreak
        self.addedDate = addedDate
    }
}

nonisolated struct FriendRequest: Codable, Identifiable, Sendable {
    let id: String
    let fromUsername: String
    let fromDisplayName: String
    let toUsername: String
    var status: FriendRequestStatus
    let sentDate: Date

    init(id: String = UUID().uuidString, fromUsername: String, fromDisplayName: String, toUsername: String, status: FriendRequestStatus = .pending, sentDate: Date = Date()) {
        self.id = id
        self.fromUsername = fromUsername
        self.fromDisplayName = fromDisplayName
        self.toUsername = toUsername
        self.status = status
        self.sentDate = sentDate
    }
}

nonisolated struct Challenge1v1: Codable, Identifiable, Sendable {
    let id: String
    let challengerUsername: String
    let challengerName: String
    let opponentUsername: String
    let opponentName: String
    var status: ChallengeStatus
    let category: String
    let sentDate: Date
    var completedDate: Date?
    var challengerScore: Double?
    var opponentScore: Double?
    var winnerUsername: String?

    init(id: String = UUID().uuidString, challengerUsername: String, challengerName: String, opponentUsername: String, opponentName: String, status: ChallengeStatus = .pending, category: String = "Physique Battle", sentDate: Date = Date(), completedDate: Date? = nil, challengerScore: Double? = nil, opponentScore: Double? = nil, winnerUsername: String? = nil) {
        self.id = id
        self.challengerUsername = challengerUsername
        self.challengerName = challengerName
        self.opponentUsername = opponentUsername
        self.opponentName = opponentName
        self.status = status
        self.category = category
        self.sentDate = sentDate
        self.completedDate = completedDate
        self.challengerScore = challengerScore
        self.opponentScore = opponentScore
        self.winnerUsername = winnerUsername
    }

    var isExpired: Bool {
        guard status == .pending else { return false }
        return Date().timeIntervalSince(sentDate) > 86400 * 3
    }
}
