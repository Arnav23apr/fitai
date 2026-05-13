import Foundation
import UIKit

struct BattleContestant {
    let name: String
    let photo: UIImage
    let overallScore: Double
    let muscleScores: MuscleScores
    let potentialRating: Double
    let visibleMuscleGroups: [String]
    let strongPoints: [String]
    let weakPoints: [String]
}

enum BattleSide {
    case player, opponent, tie
}

struct MuscleComparison: Identifiable {
    let id: String
    let label: String
    let playerScore: Double
    let opponentScore: Double

    var winner: BattleSide {
        if playerScore > opponentScore { return .player }
        if opponentScore > playerScore { return .opponent }
        return .tie
    }

    var difference: Double { abs(playerScore - opponentScore) }
}

struct PhysiqueBattle: Identifiable {
    let id: String = UUID().uuidString
    let date: Date = Date()
    let player: BattleContestant
    let opponent: BattleContestant
    /// Filled in after analysis by BattleViewModel.generateVerdict. Nil if the
    /// AI call failed or timed out — the view simply omits the verdict block.
    var verdict: String? = nil

    /// Tie threshold. AI-scored physiques are floats so an exact
    /// equality check would almost never fire in practice; a
    /// fractional gap of < 0.05 points is treated as a draw so
    /// scores like 73.0 vs 73.04 are correctly called as tied. Bump
    /// this if we ever want a wider "essentially tied" band.
    static let tieMargin: Double = 0.05

    /// Overall battle outcome. Use this instead of `playerWins` /
    /// `winner` whenever the UI needs to handle ties (badges, copy,
    /// share cards). `winner` / `loser` still return a contestant
    /// for legacy callers — on a tie they fall back to `player`.
    var outcome: BattleSide {
        if scoreDifference < Self.tieMargin { return .tie }
        return player.overallScore > opponent.overallScore ? .player : .opponent
    }

    var isTie: Bool { outcome == .tie }

    var winner: BattleContestant {
        // Legacy convenience — collapses tie to player to avoid
        // crashing the existing call sites that string-format
        // `winner.name`. New code should check `isTie` first.
        outcome == .opponent ? opponent : player
    }

    var loser: BattleContestant {
        outcome == .opponent ? player : opponent
    }

    /// Strict win for the player — false on a tie. Now that
    /// `outcome` exists, prefer it; this is kept for the existing
    /// `isWinner: battle.playerWins` callers.
    var playerWins: Bool {
        outcome == .player
    }

    var scoreDifference: Double {
        abs(player.overallScore - opponent.overallScore)
    }

    /// Per-muscle comparison rows, only for groups where at least one side has
    /// a non-zero score. Order matches the canonical display order.
    var muscleComparisons: [MuscleComparison] {
        let pSet = Set(player.visibleMuscleGroups.map { $0.lowercased() })
        let oSet = Set(opponent.visibleMuscleGroups.map { $0.lowercased() })
        let shared = pSet.union(oSet)
        let groups: [(key: String, label: String)] = [
            ("chest", "Chest"), ("shoulders", "Shoulders"), ("back", "Back"),
            ("arms", "Arms"), ("legs", "Legs"), ("glutes", "Glutes"), ("core", "Core")
        ]
        return groups
            .filter { shared.contains($0.key) }
            .compactMap { g in
                let pScore = Self.score(for: g.key, in: player.muscleScores)
                let oScore = Self.score(for: g.key, in: opponent.muscleScores)
                if pScore <= 0 && oScore <= 0 { return nil }
                return MuscleComparison(id: g.key, label: g.label, playerScore: pScore, opponentScore: oScore)
            }
    }

    var playerMuscleWins: Int { muscleComparisons.filter { $0.winner == .player }.count }
    var opponentMuscleWins: Int { muscleComparisons.filter { $0.winner == .opponent }.count }
    var tiedMuscles: Int { muscleComparisons.filter { $0.winner == .tie }.count }

    /// Muscle group with the largest score difference. Used to surface the
    /// most decisive area in the result screen ("Biggest gap: Shoulders +45").
    var biggestGap: MuscleComparison? {
        muscleComparisons.filter { $0.difference > 0 }.max { $0.difference < $1.difference }
    }

    /// Smallest non-zero gap. Surfaces near-tied categories as bragging fuel
    /// for the loser ("Closest: Chest +5").
    var closestCategory: MuscleComparison? {
        muscleComparisons.filter { $0.difference > 0 }.min { $0.difference < $1.difference }
    }

    static func score(for key: String, in scores: MuscleScores) -> Double {
        switch key {
        case "chest": return scores.chest
        case "shoulders": return scores.shoulders
        case "back": return scores.back
        case "arms": return scores.arms
        case "legs": return scores.legs
        case "core": return scores.core
        case "glutes": return scores.glutes
        default: return 0
        }
    }
}
