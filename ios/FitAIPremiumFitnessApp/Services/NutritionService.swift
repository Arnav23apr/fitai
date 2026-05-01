import Foundation

class NutritionService {
    private let aiService = AIService()

    func generateMealPlan(profile: UserProfile) async throws -> MealPlan {
        let profileContext = ProfileContextBuilder.buildContext(from: profile)

        let systemPrompt = """
        You are a sports nutritionist. Generate a daily meal plan. \
        Return JSON with: "calories" (int), "protein" (int grams), "carbs" (int grams), "fat" (int grams), \
        "meals" (array of objects with "name", "time", "description", "calories" (int), "protein" (int), "icon" (SF Symbol)). \
        Use SF Symbol names: fork.knife, cup.and.saucer.fill, takeoutbag.and.cup.and.straw.fill, leaf.fill, carrot.fill. \
        Include 4-5 meals (breakfast, snack, lunch, snack, dinner). \
        Respond ONLY with JSON, no markdown.

        PERSONALIZATION (mandatory, not optional):
        The user profile below is authoritative. The meal plan MUST be derived from it. \
        Total calories must be calculated from the user's age, gender, weightKg, heightCm, workoutsPerWeek, and primaryGoal: \
          - Muscle building → ~250-400 kcal surplus over maintenance, protein at 1.8-2.2 g/kg bodyweight. \
          - Fat loss → ~300-500 kcal deficit, protein at 2.0-2.4 g/kg to preserve lean mass. \
          - Recomp / maintenance → near maintenance, protein at 1.6-2.0 g/kg. \
        Meal timing should pair with workoutsPerWeek (training days = higher carbs around workout, rest days = leaner carbs). \
        If your output uses a generic 2000 kcal default that ignores their stats, you have failed.

        USER PROFILE:
        \(profileContext)
        """

        let userPrompt = "Generate the daily meal plan now. Use the profile in the system message to set total calories, macros, and meal composition — do not default to generic values."

        let messages = [
            ChatAPIMessage(role: "system", text: systemPrompt),
            ChatAPIMessage(role: "user", text: userPrompt)
        ]

        let response = try await aiService.chat(messages: messages)
        return try parseMealPlan(response)
    }

    private func parseMealPlan(_ response: String) throws -> MealPlan {
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIError.decodingError
        }

        return try JSONDecoder().decode(MealPlan.self, from: data)
    }
}

nonisolated struct MealPlan: Codable, Sendable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let meals: [Meal]
}

nonisolated struct Meal: Codable, Sendable, Identifiable {
    var id: String { name + time }
    let name: String
    let time: String
    let description: String
    let calories: Int
    let protein: Int
    let icon: String?
}
