import Foundation

nonisolated struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let requiredValue: Int
    let currentValue: Int
    let xpReward: Int
    let tier: AchievementTier

    var isUnlocked: Bool { currentValue >= requiredValue }
    var progress: Double { min(Double(currentValue) / max(Double(requiredValue), 1), 1.0) }
}

nonisolated enum AchievementTier: String, Sendable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case diamond = "Diamond"

    var color: String {
        switch self {
        case .bronze: return "bronze"
        case .silver: return "silver"
        case .gold: return "gold"
        case .diamond: return "diamond"
        }
    }
}

nonisolated struct SeasonInfo: Sendable {
    let name: String
    let number: Int
    let daysRemaining: Int
    let totalDays: Int
    let exclusiveBadge: String

    var progress: Double { 1.0 - (Double(daysRemaining) / Double(totalDays)) }
}

nonisolated struct ActivityFeedItem: Identifiable, Sendable {
    let id: String
    let userName: String
    let action: String
    let detail: String
    let icon: String
    let timeAgo: String
}

nonisolated struct CompeteTier: Sendable {
    let name: String
    let minPoints: Int
    let maxPoints: Int
    let icon: String
    let glowColors: [String]

    var pointsRange: Int { maxPoints - minPoints }

    static let tiers: [CompeteTier] = [
        CompeteTier(name: "Bronze", minPoints: 0, maxPoints: 500, icon: "shield.fill", glowColors: ["bronze1", "bronze2"]),
        CompeteTier(name: "Silver", minPoints: 500, maxPoints: 2000, icon: "shield.fill", glowColors: ["silver1", "silver2"]),
        CompeteTier(name: "Gold", minPoints: 2000, maxPoints: 5000, icon: "shield.fill", glowColors: ["gold1", "gold2"]),
        CompeteTier(name: "Platinum", minPoints: 5000, maxPoints: 10000, icon: "shield.fill", glowColors: ["plat1", "plat2"]),
        CompeteTier(name: "Diamond", minPoints: 10000, maxPoints: 25000, icon: "diamond.fill", glowColors: ["dia1", "dia2"]),
    ]

    static func current(for points: Int) -> CompeteTier {
        tiers.last(where: { points >= $0.minPoints }) ?? tiers[0]
    }

    static func next(for points: Int) -> CompeteTier? {
        tiers.first(where: { points < $0.minPoints })
    }
}

nonisolated enum LeaderboardTab: String, CaseIterable, Sendable {
    case thisWeek = "This Week"
    case allTime = "All Time"
    case friends = "Friends"
}

nonisolated struct LeaderboardEntry: Identifiable, Sendable {
    let id: String
    let rank: Int
    let name: String
    let points: Int
    let tier: String
    let xpToday: Int
    let rankChange: Int
}
