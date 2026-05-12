import Foundation
import UIKit

extension PhysiqueBattle {
    /// Reconstruct a `PhysiqueBattle` from a completed friends 1v1
    /// `ChallengeRow` so the rich `BattleResultView` and
    /// `BattleShareCardView` (built for the local 1v1 flow) can render
    /// the friend battle without any UI duplication.
    ///
    /// Requires both sides' analyses to be present — pre-migration-021
    /// challenges or AI failures will return nil, in which case the
    /// caller should fall back to the legacy minimal result card.
    /// Downloads both photos from the signed Supabase URLs before
    /// constructing the contestants because `BattleContestant.photo`
    /// is a `UIImage`, not a URL.
    ///
    /// - Parameters:
    ///   - row: the challenge row from Supabase (must be status=completed
    ///          with both analyses populated).
    ///   - meUserId: the current Supabase user id. Determines which side
    ///               of the row is `player` vs `opponent`.
    ///   - meUsername: display name for the player tile ("You" if empty).
    ///   - theirUsername: display name for the opponent tile.
    static func fromChallenge(
        row: ChallengeRow,
        meUserId: String,
        meUsername: String,
        theirUsername: String
    ) async -> PhysiqueBattle? {
        guard row.status == "completed",
              let cAnalysis = row.challengerAnalysis,
              let oAnalysis = row.opponentAnalysis,
              let cPhotoURL = row.challengerPhotoURL,
              let oPhotoURL = row.opponentPhotoURL
        else { return nil }

        async let cImageT = loadImage(from: cPhotoURL)
        async let oImageT = loadImage(from: oPhotoURL)
        let cImage = await cImageT
        let oImage = await oImageT

        // Default to a 1×1 transparent image when a photo URL is broken
        // — keeps the layout intact rather than dropping the whole side.
        let fallback = UIGraphicsImageRenderer(size: .init(width: 1, height: 1))
            .image { _ in }

        let iAmChallenger = meUserId == row.challengerId
        let myAnalysis = iAmChallenger ? cAnalysis : oAnalysis
        let myImage = iAmChallenger ? cImage : oImage
        let theirAnalysis = iAmChallenger ? oAnalysis : cAnalysis
        let theirImage = iAmChallenger ? oImage : cImage

        let myName = meUsername.trimmingCharacters(in: .whitespaces).isEmpty
            ? "You"
            : "@\(meUsername)"
        let theirName = theirUsername.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Opponent"
            : "@\(theirUsername)"

        let player = BattleContestant(
            name: myName,
            photo: myImage ?? fallback,
            overallScore: myAnalysis.overallScore,
            muscleScores: myAnalysis.muscleScores.toMuscleScores(),
            potentialRating: myAnalysis.potentialRating,
            visibleMuscleGroups: myAnalysis.visibleMuscleGroups,
            strongPoints: myAnalysis.strongPoints,
            weakPoints: myAnalysis.weakPoints
        )
        let opponent = BattleContestant(
            name: theirName,
            photo: theirImage ?? fallback,
            overallScore: theirAnalysis.overallScore,
            muscleScores: theirAnalysis.muscleScores.toMuscleScores(),
            potentialRating: theirAnalysis.potentialRating,
            visibleMuscleGroups: theirAnalysis.visibleMuscleGroups,
            strongPoints: theirAnalysis.strongPoints,
            weakPoints: theirAnalysis.weakPoints
        )
        var battle = PhysiqueBattle(player: player, opponent: opponent)
        battle.verdict = row.verdict
        return battle
    }

    /// Download a JPEG from a signed Supabase storage URL and return it
    /// as a `UIImage`. Returns nil on any network / decode error so the
    /// caller can substitute a placeholder rather than crash.
    private static func loadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}
