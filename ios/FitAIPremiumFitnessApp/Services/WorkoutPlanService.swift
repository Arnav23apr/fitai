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
          Beginner female: hip thrust 30-40kg, squat 25-35kg, RDL 25-35kg, glute bridge 20-30kg, rows 15-20kg, lateral raises 3-5kg. \
          Intermediate female: hip thrust 60-90kg, squat 50-70kg, RDL 50-70kg, glute bridge 50-70kg, rows 25-40kg, lateral raises 5-8kg. \
          Advanced female: hip thrust 100-140kg, squat 80-110kg, RDL 80-110kg, glute bridge 90-130kg, rows 45-60kg, lateral raises 8-12kg. \
          Scale based on bodyweight (heavier person = slightly higher weights). \
        - For suggestedReps, use typical pyramid/descending patterns: e.g. [12,10,8,6] for strength, [15,12,12,10] for hypertrophy. \
        Use these SF Symbol names for icons: figure.strengthtraining.traditional, figure.run, \
        figure.boxing, figure.core.training, figure.mixed.cardio, figure.cooldown, bed.double.fill, \
        figure.rowing, figure.strengthtraining.functional. \
        For rest days, set isRestDay true and exercises to empty array. \
        Respond ONLY with the JSON array, no markdown or explanation. \
        STYLE: Never use em dashes (—) in any string field (workout name, focusAreas, etc.). Use commas, periods, or parentheses. Hyphens (-) in compound words are fine.

        PERSONALIZATION (mandatory, not optional):
        The user profile below is authoritative. The plan you generate MUST be derived from it, not from generic templates. \
        Number of training days = workoutsPerWeek (this is a hard constraint, exactly that many non-rest days). \
        Exercise selection MUST respect trainingLocation (no barbell work for "Home / no equipment"; full barbell work for "Gym"). \
        At least one day per week MUST be marked isWeakPointFocus=true and prioritize weakPoints muscle groups, if any are listed. \
        Volume and intensity scale with trainingExperience and trainingConfidence. \
        Exercise selection and split style must align with primaryGoal AND gender (see GENDER-SPECIFIC FOCUS below). \
        Bodyweight values for suggestedWeights must be derived from the user's actual weightKg, not assumed. \
        If your output ignores any of these fields, you have failed.

        EXERCISE SELECTION BY GENDER (mandatory):
        For FEMALE users, the split should be lower-body dominant. \
        Include at least 2 dedicated lower-body / glute days per week (or, if workoutsPerWeek <= 3, at least one). \
        Prioritize these movements when programming: hip thrust, glute bridge, Romanian deadlift, Bulgarian split squat, walking lunge, sumo deadlift, cable kickback, hip abduction, single-leg glute bridge, step-up. \
        Squat and deadlift variations are still core. Quad-heavy work (leg press, front squat) should appear but never outweigh posterior-chain work. \
        Upper-body work should focus on posture and tone (rows, lat pulldowns, rear-delt flies, light pressing), not chest mass. \
        Do not program a male-coded PPL split (chest day, arm day) unless the user explicitly listed those goals. \
        For MALE users, prefer classic strength and hypertrophy splits (PPL, Upper/Lower, Bro split) emphasizing chest, shoulders, back width, arms, and proportional leg work.

        USER PROFILE:
        \(profileContext)
        \(ProfileContextBuilder.genderEmphasis(for: profile))
        \(ProfileContextBuilder.languageInstruction(for: profile, keepExercisesEnglish: true))
        """

        let userPrompt = "Generate the weekly workout plan now. Apply every constraint from my profile in the system message: number of days, training location, weak points, experience level, body weight, and primary goal."

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
