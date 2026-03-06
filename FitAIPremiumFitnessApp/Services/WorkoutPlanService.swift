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
        "exercises" (array of objects with "name", "sets" (int), "reps" (string), "muscleGroup" (string), \
        "suggestedWeights" (array of doubles, one per set, in kg), \
        "suggestedReps" (array of ints, one per set)). \
        IMPORTANT for suggestedWeights and suggestedReps: \
        - The arrays must have exactly "sets" number of elements. \
        - For bodyweight exercises (push-ups, pull-ups, dips, planks, etc.) set suggestedWeights to [0,0,...] and provide appropriate suggestedReps. \
        - For weighted exercises, base suggestedWeights on the user's experience level, body weight, and gender: \
          Beginner male: bench 30-40kg, squat 40-50kg, overhead press 20-25kg, rows 30-35kg, curls 8-10kg, lateral raises 5-7kg. \
          Intermediate male: bench 60-80kg, squat 80-100kg, overhead press 35-45kg, rows 50-60kg, curls 12-16kg, lateral raises 8-12kg. \
          Advanced male: bench 90-120kg, squat 120-160kg, overhead press 50-65kg, rows 70-90kg, curls 18-22kg, lateral raises 14-18kg. \
          For females, use approximately 50-60% of male values. \
          Scale based on bodyweight (heavier person = slightly higher weights). \
        - For suggestedReps, use typical pyramid/descending patterns: e.g. [12,10,8,6] for strength, [15,12,12,10] for hypertrophy. \
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
        Adjust difficulty based on my training confidence and experience. \
        Include realistic suggestedWeights (in kg) and suggestedReps for each set of each exercise, \
        personalized to my body weight, experience, and goals. Use progressive rep schemes (e.g. 12,10,8,6).
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
    let suggestedWeights: [Double]?
    let suggestedReps: [Int]?
}
