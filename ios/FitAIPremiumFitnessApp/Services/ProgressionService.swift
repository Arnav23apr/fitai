import Foundation

/// Weekly "should the user progress?" checker — Option C from the design
/// pass. Pro-only, hybrid: looks at the last 7 days of workout logs, asks
/// the AI whether the user has demonstrably crushed their current plan,
/// returns a small bundle of proposed changes (or nothing if not ready).
///
/// Surfaced as a non-intrusive suggestion card on PlanView. The user
/// stays in control — Apply / Keep current. Never silently mutates
/// routines.
final class ProgressionService: @unchecked Sendable {
    static let shared = ProgressionService()

    private let ai = AIService()

    /// Build the prompt from recent logs + the user's routines, call Gemini
    /// with a strict JSON schema, parse the response. Returns nil on any
    /// failure (no progression card) or when the AI returns zero changes.
    /// Caller is responsible for the "are they Pro + is it time" gating.
    func generateSuggestion(
        profile: UserProfile,
        recentLogs: [ExerciseLog],
        routines: [Routine]
    ) async -> ProgressionSuggestion? {
        // No logs = no data to base progression on. Skip silently.
        guard !recentLogs.isEmpty else { return nil }
        guard !routines.isEmpty else { return nil }

        let langInstr = profile.selectedLanguage.lowercased() == "english"
            ? ""
            : "Respond in \(profile.selectedLanguage)."

        let system = """
        You are a strength coach reviewing a user's last 7 days of training. Decide whether they are ready to progress on any of their exercises.

        Rules:
        - Be CONSERVATIVE. Only propose changes when the data clearly supports it (e.g. they hit the top of their rep range across multiple sessions at a stable weight).
        - If they didn't train enough, missed reps, or progression is ambiguous, return an empty changes array. Empty is the correct answer most of the time.
        - When changes is empty, the `summary` field MUST contain a short, actionable next step in plain English (one or two sentences, under 30 words). Examples: "Log all working sets next week so I can spot patterns." / "Repeat this week's plan. Try to hit 10 reps on every set." / "You skipped 4 sessions. Show up this week and we'll reassess." This summary will be shown to the user verbatim, so make it punchy and direct, not generic advice.
        - When changes is non-empty, `summary` should explain in one sentence WHY you're proposing progression ("You hit the top of every rep range across 3 sessions of Bench Press").
        - The `headline` field is a 3-5 word title. For empty changes use something like "Hold this week", "Repeat the plan", "Need more data". For non-empty changes use "Ready to progress", "Time to bump it", etc.
        - Cap proposals at 3 exercises. Quality over coverage.
        - Each change is a rep-range bump OR a set-count bump on an existing exercise. Do not propose new exercises or swaps in this version.
        - Never use em dashes. Use commas, periods, or parentheses instead.
        \(langInstr)
        """

        let logsSummary = recentLogs.prefix(40).map { log -> String in
            let sets = log.sets.filter(\.countsTowardVolume)
            let topSet = sets.max(by: { $0.weight < $1.weight })
            let repsRange = "\(sets.map(\.reps).min() ?? 0)-\(sets.map(\.reps).max() ?? 0)"
            return "- \(log.exerciseName) (\(log.muscleGroup)): \(sets.count) sets, weight \(Int(topSet?.weight ?? 0))kg, reps \(repsRange)"
        }.joined(separator: "\n")

        let routinesSummary = routines.flatMap { routine -> [String] in
            routine.exercises.map { ex in
                "- \(ex.name): \(ex.sets) sets, \(ex.reps) reps (\(routine.name))"
            }
        }.joined(separator: "\n")

        let user = """
        Goal: \(profile.primaryGoal.isEmpty ? "general fitness" : profile.primaryGoal)
        Experience: \(profile.trainingExperience.isEmpty ? "intermediate" : profile.trainingExperience)
        Workouts per week target: \(profile.workoutsPerWeek)

        Last 7 days of working sets:
        \(logsSummary.isEmpty ? "(no recent logs)" : logsSummary)

        Current routine exercises:
        \(routinesSummary.isEmpty ? "(no routines)" : routinesSummary)

        Should they progress this week? If yes, return a small set of concrete bumps. If they need another week at the current plan, return an empty `changes` array.
        """

        let schema: [String: AnyCodable] = responseSchema()

        do {
            let raw = try await ai.chatJSON(systemPrompt: system, userPrompt: user, schema: schema)
            return parse(raw)
        } catch {
            return nil
        }
    }

    // MARK: - Parsing

    private func parse(_ raw: String) -> ProgressionSuggestion? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let headline = (obj["headline"] as? String) ?? "Coach review"
        let summary = (obj["summary"] as? String) ?? ""
        let changesArr = (obj["changes"] as? [[String: Any]]) ?? []
        let changes: [ExerciseChange] = changesArr.compactMap { dict in
            guard let name = dict["exerciseName"] as? String,
                  let label = dict["label"] as? String else { return nil }
            return ExerciseChange(
                exerciseName: name,
                label: label,
                reason: (dict["reason"] as? String) ?? "",
                newReps: dict["newReps"] as? String,
                newSets: dict["newSets"] as? Int
            )
        }
        // Empty changes is a valid outcome — the AI looked at the data
        // and decided "not enough evidence yet." The summary tells the
        // user what to do next (log more, repeat the plan, etc.) so
        // surface that as an insight card. Only bail out when summary
        // is also blank — at that point there's truly nothing useful.
        guard !changes.isEmpty || !summary.isEmpty else { return nil }
        return ProgressionSuggestion(
            headline: headline,
            summary: summary,
            changes: changes
        )
    }

    // MARK: - Schema

    private func responseSchema() -> [String: AnyCodable] {
        let changeSpec: [String: Any] = [
            "type": "object",
            "properties": [
                "exerciseName": ["type": "string"],
                "label": ["type": "string"],
                "reason": ["type": "string"],
                "newReps": ["type": "string"],
                "newSets": ["type": "integer"]
            ],
            "required": ["exerciseName", "label"]
        ]
        return [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "headline": ["type": "string"],
                "summary": ["type": "string"],
                "changes": ["type": "array", "items": changeSpec]
            ]),
            "required": AnyCodable(["headline", "changes"])
        ]
    }

    // MARK: - Apply

    /// Walk each `ExerciseChange` and patch the matching exercise in
    /// every passed-in routine. Match is case-insensitive on `name`.
    /// Returns the count of exercises actually updated — caller can use
    /// this to decide whether to show a toast.
    ///
    /// Takes the routine list as input rather than pulling from
    /// `RoutineService.routines` so the caller can supply either saved
    /// templates OR routines materialized from the procedural AI plan.
    /// This is how progression works for Pro users who never explicitly
    /// saved a template: PlanView synthesizes routines from `workoutPlan`
    /// and hands them here. Each modified routine is persisted via
    /// `RoutineService.save`, which inserts if new (first-time
    /// materialization → graduates the user from AI plan to user-owned
    /// templates) or updates if existing (template was already saved).
    @MainActor
    func apply(_ suggestion: ProgressionSuggestion, against inputRoutines: [Routine]) -> Int {
        var updatedCount = 0
        var routines = inputRoutines
        for change in suggestion.changes {
            let key = change.exerciseName.lowercased()
            for rIdx in routines.indices {
                var routine = routines[rIdx]
                var didChange = false
                for eIdx in routine.exercises.indices where routine.exercises[eIdx].name.lowercased() == key {
                    if let reps = change.newReps {
                        routine.exercises[eIdx].reps = reps
                        didChange = true
                    }
                    if let sets = change.newSets {
                        routine.exercises[eIdx].sets = max(1, min(10, sets))
                        didChange = true
                    }
                }
                if didChange {
                    routine.updatedAt = Date()
                    // RoutineService.save returns Bool; persist via the
                    // public API so isPremium/cap logic stays centralized.
                    // Apply only fires for Pro users, so the cap doesn't
                    // matter here, but threading isPremium correctly is
                    // a cheap safety net.
                    _ = RoutineService.shared.save(routine, isPremium: true)
                    routines[rIdx] = routine
                    updatedCount += 1
                }
            }
        }
        return updatedCount
    }
}
