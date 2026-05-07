import SwiftUI
import PhotosUI

@Observable
@MainActor
class BattleViewModel {
    var playerName: String = "You"
    var opponentName: String = ""
    var playerPhoto: UIImage? = nil
    var opponentPhoto: UIImage? = nil
    var playerPickerItem: PhotosPickerItem? = nil
    var opponentPickerItem: PhotosPickerItem? = nil

    /// Whether the current player photo came from the saved default.
    var playerPhotoIsDefault: Bool = false

    /// Pre-fill the player's photo from saved battle photo, falling back to
    /// profile photo. Called by BattleSetupView on appear.
    func prefillPlayerPhoto(battlePhotoData: Data?, profileData: Data?, name: String) {
        if playerPhoto == nil {
            if let data = battlePhotoData, let image = UIImage(data: data) {
                playerPhoto = image
                playerPhotoIsDefault = true
            } else if let data = profileData, let image = UIImage(data: data) {
                playerPhoto = image
            }
        }
        if !name.isEmpty {
            playerName = name
        }
    }

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

    func startBattle(profile: UserProfile? = nil) async {
        guard let pPhoto = playerPhoto, let oPhoto = opponentPhoto else { return }
        isAnalyzing = true
        errorMessage = nil
        let lang = profile?.selectedLanguage ?? "English"
        analyzeProgress = L.t("analyzingYourPhysique", lang)

        // Hold the analyzing overlay for at least this long so the rotating
        // phrases get to play out — see the same pattern in ScanViewModel.
        let analyzeStart = Date()
        let minimumDuration: TimeInterval = 7.0

        do {
            let playerResult = try await analyzePhoto(pPhoto, profile: profile)
            let opponentDisplay = opponentName.isEmpty ? L.t("opponentTitle", lang) : opponentName
            analyzeProgress = L.t("analyzingOpponentPhysiqueFmt", lang)
                .replacingOccurrences(of: "%@", with: opponentDisplay)
            let opponentResult = try await analyzePhoto(oPhoto, profile: profile)

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

            await pauseUntilMinimumElapsed(start: analyzeStart, minimum: minimumDuration)

            isAnalyzing = false
            showResult = true
        } catch {
            await pauseUntilMinimumElapsed(start: analyzeStart, minimum: minimumDuration)
            errorMessage = error.localizedDescription
            isAnalyzing = false
        }
    }

    /// Sleep the remainder of the minimum duration if the AI returned faster.
    /// Mirrors ScanViewModel's helper — keeps the analyzing overlay visible
    /// for at least `minimum` seconds so the phrase rotation plays out.
    private func pauseUntilMinimumElapsed(start: Date, minimum: TimeInterval) async {
        let elapsed = Date().timeIntervalSince(start)
        let remaining = minimum - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
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

    private func analyzePhoto(_ image: UIImage, profile: UserProfile? = nil) async throws -> AnalysisResult {
        guard let base64 = AIService.imageToBase64(image) else {
            throw AIError.decodingError
        }

        let langInstruction = profile.map { ProfileContextBuilder.languageInstruction(for: $0) } ?? ""
        let genderEmphasis = profile.map { ProfileContextBuilder.genderEmphasis(for: $0) } ?? ""
        let systemPrompt = """
        You are a professional fitness physique analyzer. Analyze the user's physique photo and provide a detailed assessment. \
        Score from 1-10. Be honest. Consider muscle development, symmetry, proportions, and overall conditioning. \
        Most average gym-goers score 4-6. Only elite physiques score 8+. \
        IMPORTANT: Determine which muscle groups are actually VISIBLE in the photo. Only include groups you can clearly see. \
        For visibleMuscleGroups, use these exact values: "chest", "shoulders", "back", "arms", "legs", "core", "glutes". \
        For female users, "glutes" is the highest-priority muscle group — always include it when any lower body or back view is visible, and always provide a muscleScores.glutes value. \
        Only include a muscle group if it is clearly visible. Set muscleScores to 0 for non-visible groups. \
        Score visible muscle groups from 1-10 each. \
        For potentialRating, rate from 1-10 how much genetic/frame potential this person has. \
        Consider bone structure, proportions, and muscle insertions relevant to the user's goals. Be generous — most people score 7+.
        \(genderEmphasis)
        \(langInstruction)
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
                core: parseDouble(ms["core"]),
                glutes: parseDouble(ms["glutes"])
            )
        } else {
            scores = MuscleScores(chest: 0, shoulders: 0, back: 0, arms: 0, legs: 0, core: 0, glutes: 0)
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
