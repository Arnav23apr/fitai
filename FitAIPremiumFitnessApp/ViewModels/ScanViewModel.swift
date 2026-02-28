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

        do {
            guard let frontBase64 = AIService.imageToBase64(frontImg) else {
                throw AIError.decodingError
            }

            let systemPrompt = """
            You are a professional fitness physique analyzer. Analyze the user's physique photo and provide a detailed assessment. \
            Score from 1-10. Be honest but encouraging. Consider muscle development, symmetry, proportions, and overall conditioning. \
            Most average gym-goers score 4-6. Only elite physiques score 8+. \
            IMPORTANT: Determine which muscle groups are actually VISIBLE in the photo. Only include groups you can clearly see. \
            For visibleMuscleGroups, use these exact values: "chest", "shoulders", "back", "arms", "legs", "core". \
            Only include a muscle group if it is clearly visible. Set muscleScores to 0 for non-visible groups. \
            Score visible muscle groups from 1-10 each. \
            For potentialRating, rate from 1-10 how much genetic/frame potential this person has to build an amazing physique. \
            Consider bone structure, frame width, muscle insertion points, and overall proportions. \
            Be generous and motivating — most people should score 7+. This is about their POTENTIAL, not current state.
            """

            let profileContext = ProfileContextBuilder.buildContext(from: profile)
            var userPrompt = """
            Analyze this physique photo. Here is my profile:
            \(profileContext)
            
            Consider my age, body stats, goals, and experience level when scoring and giving recommendations.
            """

            let object = try await aiService.analyzeImageWithSchema(
                imageBase64: frontBase64,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )

            let result = parseScanResultFromObject(object, photo: frontImg)
            analysisResult = result
            showResults = true
            isAnalyzing = false
            return result
        } catch {
            errorMessage = error.localizedDescription
            isAnalyzing = false
            return nil
        }
    }

    func generateTransformation(profile: UserProfile) async {
        guard let frontImg = frontImage else { return }
        isGeneratingTransformation = true
        errorMessage = nil

        do {
            guard let base64 = AIService.imageToBase64(frontImg) else {
                throw AIError.decodingError
            }

            var goalDescription = "improved muscle mass and lower body fat"
            if !profile.primaryGoal.isEmpty {
                goalDescription = profile.primaryGoal.lowercased()
            }

            let prompt = """
            Transform this person's physique to show a realistic 90-day fitness transformation result. \
            The goal is: \(goalDescription). \
            Show improved muscle definition, better posture, and a more athletic build. \
            Keep the same person, same clothing style, same background. \
            Make the transformation realistic and achievable in 90 days with consistent training. \
            Do NOT add any text, watermarks, or labels to the image.
            """

            let transformedImage = try await aiService.editImage(
                prompt: prompt,
                imageBase64: base64,
                aspectRatio: "3:4"
            )

            transformationResult = TransformationResult(
                image: transformedImage,
                description: "Your potential physique after 90 days of consistent \(goalDescription) training"
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
                core: parseDouble(ms["core"])
            )
        } else {
            scores = MuscleScores(chest: 0, shoulders: 0, back: 0, arms: 0, legs: 0, core: 0)
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
}
