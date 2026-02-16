import SwiftUI
import PhotosUI

@Observable
class BattleViewModel {
    var playerName: String = "You"
    var opponentName: String = ""
    var playerPhoto: UIImage? = nil
    var opponentPhoto: UIImage? = nil
    var playerPickerItem: PhotosPickerItem? = nil
    var opponentPickerItem: PhotosPickerItem? = nil

    var isAnalyzing: Bool = false
    var analyzeProgress: String = ""
    var errorMessage: String? = nil
    var battleResult: PhysiqueBattle? = nil
    var showResult: Bool = false

    private let aiService = AIService()

    var canStartBattle: Bool {
        playerPhoto != nil && opponentPhoto != nil && !opponentName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func loadPlayerPhoto() async {
        guard let item = playerPickerItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            playerPhoto = image
        }
    }

    func loadOpponentPhoto() async {
        guard let item = opponentPickerItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            opponentPhoto = image
        }
    }

    func startBattle() async {
        guard let pPhoto = playerPhoto, let oPhoto = opponentPhoto else { return }
        isAnalyzing = true
        errorMessage = nil
        analyzeProgress = "Analyzing your physique..."

        do {
            let playerResult = try await analyzePhoto(pPhoto)
            analyzeProgress = "Analyzing \(opponentName.isEmpty ? "opponent" : opponentName)'s physique..."
            let opponentResult = try await analyzePhoto(oPhoto)

            let player = BattleContestant(
                name: playerName.isEmpty ? "You" : playerName,
                photo: pPhoto,
                overallScore: playerResult.overallScore,
                muscleScores: playerResult.muscleScores,
                potentialRating: playerResult.potentialRating,
                visibleMuscleGroups: playerResult.visibleMuscleGroups,
                strongPoints: playerResult.strongPoints,
                weakPoints: playerResult.weakPoints
            )

            let opponent = BattleContestant(
                name: opponentName.trimmingCharacters(in: .whitespaces),
                photo: oPhoto,
                overallScore: opponentResult.overallScore,
                muscleScores: opponentResult.muscleScores,
                potentialRating: opponentResult.potentialRating,
                visibleMuscleGroups: opponentResult.visibleMuscleGroups,
                strongPoints: opponentResult.strongPoints,
                weakPoints: opponentResult.weakPoints
            )

            battleResult = PhysiqueBattle(player: player, opponent: opponent)
            isAnalyzing = false
            showResult = true
        } catch {
            errorMessage = error.localizedDescription
            isAnalyzing = false
        }
    }

    func reset() {
        playerPhoto = nil
        opponentPhoto = nil
        playerPickerItem = nil
        opponentPickerItem = nil
        opponentName = ""
        battleResult = nil
        showResult = false
        errorMessage = nil
        analyzeProgress = ""
    }

    private func analyzePhoto(_ image: UIImage) async throws -> AnalysisResult {
        guard let base64 = AIService.imageToBase64(image) else {
            throw AIError.decodingError
        }

        let systemPrompt = """
        You are a professional fitness physique analyzer. Analyze the user's physique photo and provide a detailed assessment. \
        Score from 1-10. Be honest. Consider muscle development, symmetry, proportions, and overall conditioning. \
        Most average gym-goers score 4-6. Only elite physiques score 8+. \
        IMPORTANT: Determine which muscle groups are actually VISIBLE in the photo. Only include groups you can clearly see. \
        For visibleMuscleGroups, use these exact values: "chest", "shoulders", "back", "arms", "legs", "core". \
        Only include a muscle group if it is clearly visible. Set muscleScores to 0 for non-visible groups. \
        Score visible muscle groups from 1-10 each. \
        For potentialRating, rate from 1-10 how much genetic/frame potential this person has. \
        Consider bone structure, frame width, muscle insertions, proportions. Be generous — most people score 7+.
        """

        let userPrompt = "Analyze this physique photo for a 1v1 physique battle comparison. Be precise with scores."

        let object = try await aiService.analyzeImageWithSchema(
            imageBase64: base64,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        return parseAnalysis(object)
    }

    private func parseAnalysis(_ json: [String: Any]) -> AnalysisResult {
        let score: Double
        if let s = json["overallScore"] as? Double { score = s }
        else if let s = json["overallScore"] as? Int { score = Double(s) }
        else { score = 5.0 }

        let strong = (json["strongPoints"] as? [String]) ?? []
        let weak = (json["weakPoints"] as? [String]) ?? []
        let pr: Double
        if let p = json["potentialRating"] as? Double { pr = p }
        else if let p = json["potentialRating"] as? Int { pr = Double(p) }
        else { pr = 8.0 }
        let visible = (json["visibleMuscleGroups"] as? [String]) ?? []

        let scores: MuscleScores
        if let ms = json["muscleScores"] as? [String: Any] {
            scores = MuscleScores(
                chest: parseDouble(ms["chest"]),
                shoulders: parseDouble(ms["shoulders"]),
                back: parseDouble(ms["back"]),
                arms: parseDouble(ms["arms"]),
                legs: parseDouble(ms["legs"]),
                core: parseDouble(ms["core"])
            )
        } else {
            scores = MuscleScores(chest: 0, shoulders: 0, back: 0, arms: 0, legs: 0, core: 0)
        }

        return AnalysisResult(
            overallScore: score,
            muscleScores: scores,
            potentialRating: pr,
            visibleMuscleGroups: visible,
            strongPoints: strong,
            weakPoints: weak
        )
    }

    private func parseDouble(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return 0
    }
}

struct AnalysisResult {
    let overallScore: Double
    let muscleScores: MuscleScores
    let potentialRating: Double
    let visibleMuscleGroups: [String]
    let strongPoints: [String]
    let weakPoints: [String]
}
