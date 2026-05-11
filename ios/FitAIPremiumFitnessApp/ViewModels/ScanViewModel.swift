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
            let backBase64: String? = backImage.flatMap { AIService.imageToBase64($0) }

            // Build the image array in display order so the prompt's
            // "first image is front, second is back" wording matches what
            // the AI receives.
            var images: [String] = [frontBase64]
            if let back = backBase64 { images.append(back) }
            let hasBack = images.count > 1

            let profileContext = ProfileContextBuilder.buildContext(from: profile)

            let viewsDescription = hasBack
                ? "TWO photos are provided: image 1 is a FRONT view, image 2 is a BACK view. Treat them as the same person from two angles, NOT two separate physiques."
                : "ONE photo is provided: a single view of the user."

            let g = profile.gender.lowercased()
            let isFemale = g.contains("female") || g == "woman" || g == "f"

            // Gender-specific hard rules. Phrased as direct commands rather
            // than conditionals so the model can't fail by mis-applying the
            // branch — we already know the user's gender, no reason to make
            // the AI re-derive it.
            let legsRule: String
            let glutesRule: String
            if isFemale {
                legsRule = """
                LEGS — THIS USER IS FEMALE. "legs" is visible whenever the lower body is in frame, INCLUDING when covered by leggings, tight pants, sweatpants, jeans, pyjamas, or any clothing. Female leg assessment is based on SHAPE, CONTOUR, and SILHOUETTE through the clothing — not bare muscle definition. Score legs from the silhouette. Only omit "legs" if the lower body is genuinely cropped out of frame (above the hips).
                """
                glutesRule = """
                GLUTES — THIS USER IS FEMALE. "glutes" is visible whenever the glute area is in frame, INCLUDING when covered by leggings, tight pants, sweatpants, or jeans. Score from shape and silhouette. Only omit if the glute area is cropped out of frame.
                """
            } else {
                legsRule = """
                LEGS — THIS USER IS MALE. "legs" is NOT visible unless the lower body is bare or in shorts that expose at least mid-thigh AND the quads/hamstrings/calves are clearly framed. Full-length pants, sweatpants, joggers, jeans, pyjamas, track pants, or anything that covers to the ankles → DO NOT score legs. You MUST omit "legs" from visibleMuscleGroups and set muscleScores.legs = 0. When in doubt, omit. This is non-negotiable.
                """
                glutesRule = """
                GLUTES — THIS USER IS NOT FEMALE. "glutes" is a female-only metric in this product. You MUST omit "glutes" from visibleMuscleGroups and set muscleScores.glutes = 0, regardless of what the photo shows. Do not score glutes under any circumstance.
                """
            }

            let systemPrompt = """
            You are a professional fitness physique analyzer. Analyze the user's physique photos and provide a detailed assessment. \
            Score from 1-10. Be honest but encouraging. Consider muscle development, symmetry, proportions, and overall conditioning. \
            Most average gym-goers score 4-6. Only elite physiques score 8+. \

            INPUT IMAGES:
            \(viewsDescription)

            VISIBILITY RULES (mandatory — read carefully):
            For visibleMuscleGroups, use these exact values: "chest", "shoulders", "back", "arms", "legs", "core", "glutes". \
            For UPPER-BODY muscles (chest, shoulders, back, arms, core), a group is visible if you can clearly identify the muscle in ANY of the supplied photos. With both a front and a back photo of an unclothed upper body, expect chest, shoulders, arms, core, and back to all be visible — do not omit them. Shirt covering the abdomen → "core" is NOT visible. Only a front photo, no back view → "back" is NOT visible. \

            \(legsRule)

            \(glutesRule)

            For ANY muscle group ruled NOT visible above, omit it from visibleMuscleGroups AND set muscleScores.<group> to exactly 0. Returning a non-zero score for a muscle that is not visible per these rules is a failure — but failing to score a muscle that IS visible per these rules is also a failure. \

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

            let userPrompt = hasBack
                ? "Analyze these physique photos (front + back). Apply the profile from the system message in every part of your response — scoring, weak/strong points, and recommendations."
                : "Analyze this physique photo. Apply the profile from the system message in every part of your response — scoring, weak/strong points, and recommendations."

            let object = try await aiService.analyzeImagesWithSchema(
                imagesBase64: images,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )

            let result = parseScanResultFromObject(object, photo: frontImg, gender: profile.gender)
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

    /// Free-tier scan path: shows the same analyzing animation as the real scan,
    /// holds the same minimum duration, but does NOT call the AI. Returns a
    /// locked placeholder result that the ScanResultsSheet renders blurred,
    /// gated behind the paywall. This zeroes out free-tier AI cost without
    /// breaking the experience flow (free users still feel the value moment;
    /// they just have to upgrade to see their actual numbers).
    func analyzeScanLocked(profile: UserProfile) async -> ScanResult? {
        guard let frontImg = frontImage else { return nil }
        isAnalyzing = true
        errorMessage = nil

        let analyzeStart = Date()
        let minimumDuration: TimeInterval = 7.0

        await pauseUntilMinimumElapsed(start: analyzeStart, minimum: minimumDuration)

        // Plausible placeholder values so the UI renders structure correctly
        // even when blurred. Real numbers stay hidden behind the paywall.
        let result = ScanResult(
            date: Date(),
            overallScore: 6.5,
            strongPoints: ["chest", "shoulders"],
            weakPoints: ["legs", "core"],
            summary: "Unlock Pro to see your real summary.",
            recommendations: [
                "Unlock Pro to see your custom plan.",
                "Unlock Pro to see your weak-point coach.",
                "Unlock Pro to see your full breakdown.",
            ],
            potentialRating: 8.0,
            muscleMassRating: "Locked",
            muscleScores: MuscleScores(chest: 7, shoulders: 7, back: 6, arms: 6,
                                       legs: 5, core: 5, glutes: 0),
            visibleMuscleGroups: ["chest", "shoulders", "back", "arms", "legs", "core"],
            frontPhoto: frontImg,
            isLocked: true
        )

        analysisResult = result
        showResults = true
        isAnalyzing = false
        return result
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

            // Prompt structured per Nano Banana Pro best-practice research:
            // imperative direction, positive framing throughout (no "do not"
            // sections — Google's guidance is that negations parse weakly
            // through the diffusion process and reduce compliance), and an
            // explicit preservation list anchored with concrete examples so
            // the model has unambiguous targets for what to lock vs. what
            // to modify.
            let prompt = """
            You are editing a photograph of a real person to show their realistic 90-day fitness transformation. The output must look like the same photograph of the same person on the same day, just 90 days into their training. Their stated goal: \(goalDescription).

            The only changes you may make are to the person's physique:
            1. Add the visible muscle definition that consistent training builds over 90 days — roughly 2–3 lb of lean mass for men, 1–2 lb for women. Show natural shape and definition, not stage-condition or bodybuilder-level mass.
            2. Reduce body fat by approximately 2–4 percentage points so existing muscle becomes more visible. Show natural definition, not extreme cuts.
            3. Subtly improve posture: shoulders set back, chest open, core engaged. Keep the change small enough that the pose itself is unchanged.

            \(physiqueDirection)

            Keep every other element of the photograph exactly as it appears in the original:
            - The pose is locked: same body angle, same head tilt, same arm position, same hand position, same finger position, same leg position, same weight distribution, same camera angle. If their left arm is bent at 90° in the original, it stays bent at 90° in the output. If their head is tilted slightly down, it stays tilted slightly down.
            - Anything in their hands stays in their hands. If they are holding a phone, water bottle, dumbbell, towel, gym bag, drink, AirPods case, or any other object, that object remains in the same hand at the same angle. Mirror selfies keep the phone in their hand exactly as it appears in the original.
            - The face and identity remain unchanged: same facial features, same expression, same hairstyle, same haircut, same facial hair, same skin tone, same ethnicity, same eye color. The output is the same person.
            - Clothing remains identical: same garments, same color, same fit, same coverage. If shirtless in the original, the output is shirtless. If wearing a tank top, the output keeps the tank top.
            - Background remains identical: same setting, same lighting direction, same lighting color, same shadows, same objects in the room, same wall texture, same floor. Mirror selfies keep the mirror, the room reflected behind them, and the original reflections intact.
            - Framing remains identical: same crop, same camera distance, same zoom level, same aspect ratio.
            - Skin texture remains natural: keep blemishes, body hair, scars, tattoos, birthmarks, freckles, and all natural shadows. Do not smooth or airbrush.
            - Camera character remains the same: match the original photo's lens distortion, depth of field, color grade, and noise/grain. Front-camera selfies keep the slight wide-angle face distortion; rear-camera shots keep their flatter perspective.

            Output is a clean photograph with no overlaid text, no watermarks, no logos, no graphic elements, and no stylization — indistinguishable from the original photograph in every respect except the person's physique.
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

    private func parseScanResultFromObject(_ json: [String: Any], photo: UIImage?, gender: String) -> ScanResult {
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
        var visible = (json["visibleMuscleGroups"] as? [String]) ?? []

        // Defense in depth — strip glutes for non-female users even if the
        // AI ignored the gender rule in the prompt. Glutes is a female-only
        // muscle group in this product.
        let g = gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"
        if !isFemale {
            visible.removeAll { $0.lowercased() == "glutes" }
        }

        let glutesScore: Double
        if let ms = json["muscleScores"] as? [String: Any] {
            glutesScore = isFemale ? parseDouble(ms["glutes"]) : 0
        } else {
            glutesScore = 0
        }

        let scores: MuscleScores
        if let ms = json["muscleScores"] as? [String: Any] {
            scores = MuscleScores(
                chest: parseDouble(ms["chest"]),
                shoulders: parseDouble(ms["shoulders"]),
                back: parseDouble(ms["back"]),
                arms: parseDouble(ms["arms"]),
                legs: parseDouble(ms["legs"]),
                core: parseDouble(ms["core"]),
                glutes: glutesScore
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
