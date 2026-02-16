import Foundation
import UIKit

struct BattleContestant {
    let name: String
    let photo: UIImage
    let overallScore: Double
    let muscleScores: MuscleScores
    let bodyFatEstimate: String
    let visibleMuscleGroups: [String]
    let strongPoints: [String]
    let weakPoints: [String]
}

struct PhysiqueBattle: Identifiable {
    let id: String = UUID().uuidString
    let date: Date = Date()
    let player: BattleContestant
    let opponent: BattleContestant

    var winner: BattleContestant {
        player.overallScore >= opponent.overallScore ? player : opponent
    }

    var loser: BattleContestant {
        player.overallScore >= opponent.overallScore ? opponent : player
    }

    var playerWins: Bool {
        player.overallScore >= opponent.overallScore
    }

    var scoreDifference: Double {
        abs(player.overallScore - opponent.overallScore)
    }
}
