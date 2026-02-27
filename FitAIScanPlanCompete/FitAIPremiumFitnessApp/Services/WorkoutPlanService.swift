import Foundation

class WorkoutPlanService {
    private let aiService = AIService()

    func generateAIPlan(profile: UserProfile) async throws -> [WorkoutDayData] {
        let systemPrompt = """
        You are a certified personal trainer creating a weekly workout plan. \
        Return a JSON array of 7 days (Monday-Sunday). Each day object has: \
        "dayLabel" (MON/TUE/WED/THU/FRI/SAT/SUN), "name" (workout name), \
        "focusAreas" (array of muscle groups), "icon" (SF Symbol name), \
        "isRestDay" (boolean), "isWeakPointFocus" (boolean), \
        "exercises" (array of objects with "name", "sets" (int), "reps" (string), "muscleGroup" (string)). \
        Use these SF Symbol names for icons: figure.strengthtraining.traditional, figure.run, \
        figure.boxing, figure.core.training, figure.mixed.cardio, figure.cooldown, bed.double.fill, \
        figure.rowing, figure.strengthtraining.functional. \
        For rest days, set isRestDay true and exercises to empty array. \
        Respond ONLY with the JSON array, no markdown or explanation.
        """

        let profileContext = ProfileContextBuilder.buildContext(from: profile)
        let userPrompt = """
        Create a personalized weekly workout plan based on my profile:
        \(profileContext)
        
        Tailor the exercises, volume, and intensity to my experience level, goals, body stats, and training location. \
        If I have weak points, prioritize exercises that target them. \
        Adjust difficulty based on my training confidence and experience.
        """

        let messages = [
            ChatAPIMessage(role: "system", text: systemPrompt),
            ChatAPIMessage(role: "user", text: userPrompt)
        ]

        let response = try await aiService.chat(messages: messages)
        return try parseWorkoutPlan(response)
    }

    private func parseWorkoutPlan(_ response: String) throws -> [WorkoutDayData] {
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

        let decoded = try JSONDecoder().decode([WorkoutDayData].self, from: data)
        return decoded
    }
}

nonisolated struct WorkoutDayData: Codable, Sendable, Identifiable {
    var id: String { dayLabel }
    let dayLabel: String
    let name: String
    let focusAreas: [String]
    let icon: String
    let isRestDay: Bool
    let isWeakPointFocus: Bool
    let exercises: [ExerciseData]
}

nonisolated struct ExerciseData: Codable, Sendable, Identifiable {
    var id: String { name + muscleGroup }
    let name: String
    let sets: Int
    let reps: String
    let muscleGroup: String
}
