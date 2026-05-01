import Foundation

class WorkoutPlanService {
    private let aiService = AIService()

    func generateAIPlan(profile: UserProfile) async throws -> [WorkoutDayData] {
        let profileContext = ProfileContextBuilder.buildContext(from: profile)

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

        PERSONALIZATION (mandatory, not optional):
        The user profile below is authoritative. The plan you generate MUST be derived from it, not from generic templates. \
        Number of training days = workoutsPerWeek (this is a hard constraint — exactly that many non-rest days). \
        Exercise selection MUST respect trainingLocation (no barbell work for "Home / no equipment"; full barbell work for "Gym"). \
        At least one day per week MUST be marked isWeakPointFocus=true and prioritize weakPoints muscle groups, if any are listed. \
        Volume and intensity scale with trainingExperience and trainingConfidence. \
        Exercise selection and split style (PPL, upper/lower, full-body, etc.) must align with primaryGoal. \
        Bodyweight values for suggestedWeights must be derived from the user's actual weightKg, not assumed. \
        If your output ignores any of these fields, you have failed.

        USER PROFILE:
        \(profileContext)
        """

        let userPrompt = "Generate the weekly workout plan now. Apply every constraint from my profile in the system message — number of days, training location, weak points, experience level, body weight, and primary goal."

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
