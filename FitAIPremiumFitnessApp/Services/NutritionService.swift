import Foundation

class NutritionService {
    private let aiService = AIService()

    func generateMealPlan(profile: UserProfile) async throws -> MealPlan {
        let systemPrompt = """
        You are a sports nutritionist. Generate a daily meal plan. \
        Return JSON with: "calories" (int), "protein" (int grams), "carbs" (int grams), "fat" (int grams), \
        "meals" (array of objects with "name", "time", "description", "calories" (int), "protein" (int), "icon" (SF Symbol)). \
        Use SF Symbol names: fork.knife, cup.and.saucer.fill, takeoutbag.and.cup.and.straw.fill, leaf.fill, carrot.fill. \
        Include 4-5 meals (breakfast, snack, lunch, snack, dinner). \
        Respond ONLY with JSON, no markdown.
        """

        var userPrompt = "Create a daily meal plan for me."
        if !profile.primaryGoal.isEmpty {
            userPrompt += " Goal: \(profile.primaryGoal)."
        }
        userPrompt += " Weight: \(Int(profile.weightKg))kg. Height: \(Int(profile.heightCm))cm."
        if !profile.gender.isEmpty {
            userPrompt += " Gender: \(profile.gender)."
        }
        userPrompt += " Workouts per week: \(profile.workoutsPerWeek)."
        if !profile.trainingExperience.isEmpty {
            userPrompt += " Experience: \(profile.trainingExperience)."
        }

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
