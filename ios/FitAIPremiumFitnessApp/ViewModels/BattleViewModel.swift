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
        playerPhoto != nil && opponentPhoto != nil
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

    /// Optional fast-path for the player side. When set, we reuse this
    /// AnalysisResult instead of re-running AI on the player photo. Saves
    /// ~$0.01 per battle and ~3 seconds of latency. Caller (BattleSetupView)
    /// builds this from the user's most recent scan if it's <7 days old.
    var cachedPlayerAnalysis: AnalysisResult? = nil

    func startBattle(profile: UserProfile? = nil) async {
        guard let pPhoto = playerPhoto, let oPhoto = opponentPhoto else { return }
        isAnalyzing = true
        errorMessage = nil
        let lang = profile?.selectedLanguage ?? "English"
        analyzeProgress = L.t("analyzingYourPhysique", lang)

        // Hold the analyzing overlay for at least this long so the rotating
        // phrases get to play out, see the same pattern in ScanViewModel.
        let analyzeStart = Date()
        let minimumDuration: TimeInterval = 7.0

        do {
            // Player side: reuse the user's cached scan analysis when available
            // (cuts battle cost in half, scan results are good for 7 days).
            let playerResult: AnalysisResult
            if let cached = cachedPlayerAnalysis {
                playerResult = cached
                // small visible delay so the user still sees the "analyzing
                // your physique" phrase rotate; the actual work was zero.
                try? await Task.sleep(for: .seconds(1.5))
            } else {
                playerResult = try await analyzePhoto(pPhoto, profile: profile)
            }
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

            let trimmedOpponent = opponentName.trimmingCharacters(in: .whitespaces)
            let opponent = BattleContestant(
                name: trimmedOpponent.isEmpty ? L.t("opponentTitle", lang) : trimmedOpponent,
                photo: oPhoto,
                overallScore: opponentResult.overallScore,
                muscleScores: opponentResult.muscleScores,
                potentialRating: opponentResult.potentialRating,
                visibleMuscleGroups: opponentResult.visibleMuscleGroups,
                strongPoints: opponentResult.strongPoints,
                weakPoints: opponentResult.weakPoints
            )

            var battle = PhysiqueBattle(player: player, opponent: opponent)
            // Best-effort AI verdict — keep the existing analyze progress
            // message visible during the call. If the verdict fails or times
            // out, the result screen omits the block.
            battle.verdict = await generateVerdict(player: player, opponent: opponent, lang: lang)
            battleResult = battle

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

    /// One-line AI commentary on who won and why. Returns nil on any failure
    /// so the result screen can gracefully omit the section.
    private func generateVerdict(player: BattleContestant, opponent: BattleContestant, lang: String) async -> String? {
        let langInstr = lang.lowercased() == "english" ? "" : "Respond in \(lang)."
        let system = """
        You are a physique battle commentator. Write a single sharp sentence (under 25 words) explaining who won and why. Cite the specific muscle group or quality that decided it. Tone: confident, neutral, factual, not mean. Never use em dashes; use commas, periods, or parentheses instead. \(langInstr)
        """

        func scoreList(_ s: MuscleScores) -> String {
            "chest \(fmt(s.chest)), shoulders \(fmt(s.shoulders)), back \(fmt(s.back)), arms \(fmt(s.arms)), legs \(fmt(s.legs)), core \(fmt(s.core)), glutes \(fmt(s.glutes))"
        }

        let user = """
        \(player.name): overall \(fmt(player.overallScore))/10, scores [\(scoreList(player.muscleScores))], strong [\(player.strongPoints.joined(separator: ", "))].
        \(opponent.name): overall \(fmt(opponent.overallScore))/10, scores [\(scoreList(opponent.muscleScores))], strong [\(opponent.strongPoints.joined(separator: ", "))].

        Write the verdict in one sentence.
        """

        let messages: [ChatAPIMessage] = [
            ChatAPIMessage(role: "system", text: system),
            ChatAPIMessage(role: "user", text: user)
        ]

        do {
            let result = try await aiService.chat(messages: messages)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    private func fmt(_ d: Double) -> String { String(format: "%.1f", d) }

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
        VISIBILITY RULES (mandatory — read carefully):
        For visibleMuscleGroups, use these exact values: "chest", "shoulders", "back", "arms", "legs", "core", "glutes". \
        A muscle group is VISIBLE only if you can clearly identify the muscle itself in the photo — not inferred from the rest of the body. \
        Examples: a front-facing torso shot does NOT show back or glutes; a clothed lower body does NOT show legs; a shirt covering the abdomen does NOT show core. \
        For ANY muscle group that is not visible, you MUST omit it from visibleMuscleGroups AND set muscleScores.<group> to exactly 0. Do not guess, do not infer, do not estimate from the rest of the physique. Returning a non-zero score for a muscle you cannot see is a failure. \
        For female users, "glutes" is the highest-priority muscle group — always include it when any lower body or back view actually shows the glutes, and always provide a muscleScores.glutes value. If glutes are not in frame, score 0 like any other invisible group. \
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
