import SwiftUI
import PhotosUI

@Observable
class ScanViewModel {
    var frontImage: UIImage? = nil
    var backImage: UIImage? = nil
    var frontPickerItem: PhotosPickerItem? = nil
    var backPickerItem: PhotosPickerItem? = nil

    var isAnalyzing: Bool = false
    var isGeneratingTransformation: Bool = false
    var analysisResult: ScanResult? = nil
    var transformationResult: TransformationResult? = nil
    var errorMessage: String? = nil
    var showResults: Bool = false

    private let aiService = AIService()

    func loadFrontImage() async {
        guard let item = frontPickerItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            frontImage = image
        }
    }

    func loadBackImage() async {
        guard let item = backPickerItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            backImage = image
        }
    }

    func analyzeScan(profile: UserProfile) async -> ScanResult? {
        guard let frontImg = frontImage else { return nil }
        isAnalyzing = true
        errorMessage = nil

        // Hold the analyzing overlay for at least this long, even if the AI
        // returns faster, so the user always sees ~4-5 rotating phrases. This
        // is purely a UX-pacing decision, not a real wait — the AI result is
        // ready as soon as it lands; we just delay the dismiss.
        let analyzeStart = Date()
        let minimumDuration: TimeInterval = 7.0

        do {
            guard let frontBase64 = AIService.imageToBase64(frontImg) else {
                throw AIError.decodingError
            }

            let profileContext = ProfileContextBuilder.buildContext(from: profile)

            let systemPrompt = """
            You are a professional fitness physique analyzer. Analyze the user's physique photo and provide a detailed assessment. \
            Score from 1-10. Be honest but encouraging. Consider muscle development, symmetry, proportions, and overall conditioning. \
            Most average gym-goers score 4-6. Only elite physiques score 8+. \
            IMPORTANT: Determine which muscle groups are actually VISIBLE in the photo. Only include groups you can clearly see. \
            For visibleMuscleGroups, use these exact values: "chest", "shoulders", "back", "arms", "legs", "core", "glutes". \
            For female users, "glutes" is the highest-priority muscle group — always include it in visibleMuscleGroups when any lower body or back view is visible, and always provide a muscleScores.glutes value. \
            Only include a muscle group if it is clearly visible. Set muscleScores to 0 for non-visible groups. \
            Score visible muscle groups from 1-10 each. \
            For potentialRating, rate from 1-10 how much genetic/frame potential this person has to build an amazing physique. \
            Consider bone structure, proportions, and muscle insertion points relevant to the user's goals. \
            Be generous and motivating — most people should score 7+. This is about their POTENTIAL, not current state.

            PERSONALIZATION (mandatory, not optional):
            The user profile below is authoritative. You MUST tailor every part of your assessment to it — \
            scores must factor in their age, gender, training experience, and stated goals; \
            recommendations must directly reference their primaryGoal, weakPoints, and trainingLocation; \
            tone must match their trainingConfidence (lower = more reassuring, higher = more direct); \
            advice must acknowledge their stated obstacles (holdingBack). \
            Do NOT produce generic physique advice. If your output could be sent to any user without changes, you have failed.

            USER PROFILE:
            \(profileContext)
            \(ProfileContextBuilder.genderEmphasis(for: profile))
            \(ProfileContextBuilder.languageInstruction(for: profile))
            """

            var userPrompt = "Analyze this physique photo. Apply the profile from the system message in every part of your response — scoring, weak/strong points, and recommendations."

            let object = try await aiService.analyzeImageWithSchema(
                imageBase64: frontBase64,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )

            let result = parseScanResultFromObject(object, photo: frontImg)
            analysisResult = result

            await pauseUntilMinimumElapsed(start: analyzeStart, minimum: minimumDuration)

            showResults = true
            isAnalyzing = false
            return result
        } catch {
            await pauseUntilMinimumElapsed(start: analyzeStart, minimum: minimumDuration)
            errorMessage = error.localizedDescription
            isAnalyzing = false
            return nil
        }
    }

    /// Sleep the remainder of the minimum duration if the AI returned faster.
    /// Cancellable; if the task is cancelled mid-sleep, we just dismiss now.
    private func pauseUntilMinimumElapsed(start: Date, minimum: TimeInterval) async {
        let elapsed = Date().timeIntervalSince(start)
        let remaining = minimum - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
    }

    func generateTransformation(profile: UserProfile) async {
        guard let frontImg = frontImage else { return }
        isGeneratingTransformation = true
        errorMessage = nil

        do {
            guard let base64 = AIService.imageToBase64(frontImg) else {
                throw AIError.decodingError
            }

            var goalDescription = "improved muscle definition and lower body fat"
            if !profile.primaryGoal.isEmpty {
                goalDescription = profile.primaryGoal.lowercased()
            }

            let g = profile.gender.lowercased()
            let isFemale = g.contains("female") || g == "woman" || g == "f"
            let isMale = !isFemale && (g.contains("male") || g == "man" || g == "m")

            let physiqueDirection: String
            if isFemale {
                physiqueDirection = "Show a fitter, more toned female physique: better posture, defined waist with improved hip-to-waist ratio, fuller and lifted glutes, toned legs, lean arms. Do NOT add male-coded mass — no thick chest, no bulky biceps, no V-taper. Keep feminine proportions."
            } else if isMale {
                physiqueDirection = "Show a fitter, more athletic male physique: improved posture, broader and more defined shoulders, fuller chest, visible arm definition, leaner waist, V-taper proportions, and more developed legs."
            } else {
                physiqueDirection = "Show improved muscle definition, better posture, and a more athletic build, matching the proportions and silhouette already visible in the photo."
            }

            let prompt = """
            Transform this person's physique to show a realistic 90-day fitness transformation result. \
            The goal is: \(goalDescription). \
            \(physiqueDirection) \
            Keep the same person, same face, same clothing style, same background. \
            Make the transformation realistic and achievable in 90 days with consistent training — not bodybuilder-level. \
            Do NOT add any text, watermarks, or labels to the image.
            """

            let transformedImage = try await aiService.editImage(
                prompt: prompt,
                imageBase64: base64,
                aspectRatio: "3:4"
            )

            // Two versions of the AI photo:
            //   image: clean (used in-app + in the diptych share card)
            //   brandedImage: with disclosure band baked into the bottom,
            //                 used only as the fallback if the user grabs
            //                 the raw photo (screenshot / save-to-photos)
            //                 instead of going through the share card.
            let brandedImage = Self.bakeBrandFooter(into: transformedImage)

            transformationResult = TransformationResult(
                image: transformedImage,
                brandedImage: brandedImage,
                description: L.t("transformationDesc", profile.selectedLanguage)
                    .replacingOccurrences(of: "%@", with: goalDescription)
            )
            isGeneratingTransformation = false
        } catch {
            errorMessage = "Could not generate transformation: \(error.localizedDescription)"
            isGeneratingTransformation = false
        }
    }

    func reset() {
        frontImage = nil
        backImage = nil
        frontPickerItem = nil
        backPickerItem = nil
        analysisResult = nil
        transformationResult = nil
        errorMessage = nil
        showResults = false
    }

    private func parseScanResultFromObject(_ json: [String: Any], photo: UIImage?) -> ScanResult {
        let score: Double
        if let s = json["overallScore"] as? Double {
            score = s
        } else if let s = json["overallScore"] as? Int {
            score = Double(s)
        } else {
            score = 5.0
        }
        let strong = (json["strongPoints"] as? [String]) ?? ["Upper Body"]
        let weak = (json["weakPoints"] as? [String]) ?? ["Core"]
        let summary = (json["summary"] as? String) ?? "Analysis complete."
        let recs = (json["recommendations"] as? [String]) ?? ["Focus on weak areas"]
        let pr: Double
        if let p = json["potentialRating"] as? Double { pr = p }
        else if let p = json["potentialRating"] as? Int { pr = Double(p) }
        else { pr = 8.0 }
        let mm = (json["muscleMassRating"] as? String) ?? "Average"
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

        return ScanResult(
            date: Date(),
            overallScore: score,
            strongPoints: strong,
            weakPoints: weak,
            summary: summary,
            recommendations: recs,
            potentialRating: pr,
            muscleMassRating: mm,
            muscleScores: scores,
            visibleMuscleGroups: visible,
            frontPhoto: photo
        )
    }

    private func parseDouble(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return 0
    }

    /// Composites a branded disclosure band onto the bottom of the supplied
    /// image. The band is part of the rendered JPEG so cropping it ruins the
    /// photo's framing — the strongest realistic attribution we can bake in.
    private static func bakeBrandFooter(into image: UIImage) -> UIImage {
        let size = image.size
        let bandHeight = max(size.height * 0.07, 60)
        let outputSize = CGSize(width: size.width, height: size.height + bandHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { ctx in
            // 1. Draw original photo at the top
            image.draw(in: CGRect(origin: .zero, size: size))

            // 2. Solid black band beneath
            let bandRect = CGRect(x: 0, y: size.height, width: size.width, height: bandHeight)
            let cgCtx = ctx.cgContext
            cgCtx.saveGState()
            cgCtx.setFillColor(UIColor.black.cgColor)
            cgCtx.fill(bandRect)

            // 3. Centered disclosure + brand text
            let fontSize = bandHeight * 0.30
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: UIColor.white,
                .kern: 3.0
            ]
            let label = "AI-GENERATED · FITAI · 90 DAYS"
            let textSize = (label as NSString).size(withAttributes: attrs)
            let textOrigin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: size.height + (bandHeight - textSize.height) / 2 + 1.5
            )
            (label as NSString).draw(at: textOrigin, withAttributes: attrs)

            cgCtx.restoreGState()
        }
    }
}
