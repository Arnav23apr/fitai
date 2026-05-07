import Foundation

/// Coach-driven template operations. Three paths:
///
/// 1. **Modify** — given a `Routine`, return a list of `EditOp`s.
/// 2. **Create** — return one or more brand-new `TemplateSpec`s.
/// 3. **Clarify** — when the prompt is ambiguous, return follow-up
///    questions instead of guessing. The user reads them, refines their
///    request, and tries again.
///
/// Backed by Gemini's structured-JSON output mode (`responseMimeType:
/// application/json` + a strict response schema) so the model can't return
/// markdown-wrapped or prefixed text — every response decodes cleanly.
nonisolated struct PlanModificationService: Sendable {

    enum ModError: Error {
        case emptyResponse
        case decode
    }

    static let shared = PlanModificationService()
    private init() {}

    // MARK: - Edit ops (modify mode)

    nonisolated struct EditOp: Codable, Sendable, Identifiable {
        let id: String
        let op: String
        let target: String?
        let replacement: String?
        let muscleGroup: String?
        let position: Int?
        let sets: Int?
        let reps: String?
        let reason: String?

        init(id: String = UUID().uuidString,
             op: String,
             target: String? = nil,
             replacement: String? = nil,
             muscleGroup: String? = nil,
             position: Int? = nil,
             sets: Int? = nil,
             reps: String? = nil,
             reason: String? = nil) {
            self.id = id
            self.op = op
            self.target = target
            self.replacement = replacement
            self.muscleGroup = muscleGroup
            self.position = position
            self.sets = sets
            self.reps = reps
            self.reason = reason
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self.op = try c.decode(String.self, forKey: .op)
            self.target = try c.decodeIfPresent(String.self, forKey: .target)
            self.replacement = try c.decodeIfPresent(String.self, forKey: .replacement)
            self.muscleGroup = try c.decodeIfPresent(String.self, forKey: .muscleGroup)
            self.position = try c.decodeIfPresent(Int.self, forKey: .position)
            self.sets = try c.decodeIfPresent(Int.self, forKey: .sets)
            self.reps = try c.decodeIfPresent(String.self, forKey: .reps)
            self.reason = try c.decodeIfPresent(String.self, forKey: .reason)
        }

        var humanReadable: String {
            switch op {
            case "swap": return "Swap \(target ?? "?") → \(replacement ?? "?")"
            case "add":
                let pos = position.map { " at #\($0 + 1)" } ?? ""
                return "Add \(replacement ?? "?")\(pos)"
            case "remove": return "Remove \(target ?? "?")"
            case "change_sets": return "Change \(target ?? "?") to \(sets ?? 0) sets"
            case "change_reps": return "Change \(target ?? "?") reps → \(reps ?? "?")"
            default: return "\(op) \(target ?? "")"
            }
        }
    }

    // MARK: - Template specs (create mode)

    nonisolated struct TemplateSpec: Codable, Sendable, Identifiable {
        let id: String
        let name: String
        let icon: String
        let defaultRestSeconds: Int
        let exercises: [ExerciseSpec]
        let reason: String?

        init(id: String = UUID().uuidString,
             name: String,
             icon: String = "dumbbell.fill",
             defaultRestSeconds: Int = 90,
             exercises: [ExerciseSpec],
             reason: String? = nil) {
            self.id = id
            self.name = name
            self.icon = icon
            self.defaultRestSeconds = defaultRestSeconds
            self.exercises = exercises
            self.reason = reason
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self.name = try c.decode(String.self, forKey: .name)
            self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "dumbbell.fill"
            self.defaultRestSeconds = try c.decodeIfPresent(Int.self, forKey: .defaultRestSeconds) ?? 90
            self.exercises = try c.decode([ExerciseSpec].self, forKey: .exercises)
            self.reason = try c.decodeIfPresent(String.self, forKey: .reason)
        }

        func toRoutine() -> Routine {
            Routine(
                name: name,
                icon: icon,
                exercises: exercises.map { spec in
                    RoutineExercise(
                        name: spec.name,
                        sets: spec.sets,
                        reps: spec.reps,
                        muscleGroup: spec.muscleGroup
                    )
                },
                defaultRestSeconds: defaultRestSeconds
            )
        }
    }

    nonisolated struct ExerciseSpec: Codable, Sendable, Hashable {
        let name: String
        let sets: Int
        let reps: String
        let muscleGroup: String

        init(name: String, sets: Int, reps: String, muscleGroup: String) {
            self.name = name
            self.sets = sets
            self.reps = reps
            self.muscleGroup = muscleGroup
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try c.decode(String.self, forKey: .name)
            self.sets = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
            self.reps = try c.decodeIfPresent(String.self, forKey: .reps) ?? "8-12"
            self.muscleGroup = try c.decodeIfPresent(String.self, forKey: .muscleGroup) ?? ""
        }
    }

    // MARK: - Clarification (questions back to the user)

    nonisolated struct ClarificationRequest: Codable, Sendable {
        let questions: [String]

        init(questions: [String]) { self.questions = questions }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.questions = try c.decodeIfPresent([String].self, forKey: .questions) ?? []
        }
    }

    // MARK: - Combined response

    nonisolated struct GenerateResponse: Codable, Sendable {
        let summary: String
        let edits: [EditOp]
        let newTemplates: [TemplateSpec]
        let clarification: ClarificationRequest?

        var hasEdits: Bool { !edits.isEmpty }
        var hasNewTemplates: Bool { !newTemplates.isEmpty }
        var hasClarification: Bool { (clarification?.questions.isEmpty == false) }
        var isEmpty: Bool { !hasEdits && !hasNewTemplates && !hasClarification }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
            self.edits = try c.decodeIfPresent([EditOp].self, forKey: .edits) ?? []
            self.newTemplates = try c.decodeIfPresent([TemplateSpec].self, forKey: .newTemplates) ?? []
            self.clarification = try c.decodeIfPresent(ClarificationRequest.self, forKey: .clarification)
        }

        init(summary: String, edits: [EditOp], newTemplates: [TemplateSpec], clarification: ClarificationRequest?) {
            self.summary = summary
            self.edits = edits
            self.newTemplates = newTemplates
            self.clarification = clarification
        }
    }

    // MARK: - Plan Review (path 3)

    /// Coach's review of a user-pasted plan. Returns parsed templates plus
    /// a critique (strengths, weaknesses, suggestions) so the user gets
    /// real value before importing — not just a dumb data conversion.
    nonisolated struct PlanReview: Codable, Sendable {
        let summary: String
        let templates: [TemplateSpec]
        let critique: Critique
        let clarification: ClarificationRequest?

        struct Critique: Codable, Sendable {
            let strengths: [String]
            let weaknesses: [String]
            let suggestions: [String]

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                self.strengths = try c.decodeIfPresent([String].self, forKey: .strengths) ?? []
                self.weaknesses = try c.decodeIfPresent([String].self, forKey: .weaknesses) ?? []
                self.suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
            }

            init(strengths: [String], weaknesses: [String], suggestions: [String]) {
                self.strengths = strengths
                self.weaknesses = weaknesses
                self.suggestions = suggestions
            }
        }

        var hasContent: Bool { !templates.isEmpty || !critique.suggestions.isEmpty }
        var hasClarification: Bool { (clarification?.questions.isEmpty == false) }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
            self.templates = try c.decodeIfPresent([TemplateSpec].self, forKey: .templates) ?? []
            self.critique = (try? c.decode(Critique.self, forKey: .critique))
                ?? Critique(strengths: [], weaknesses: [], suggestions: [])
            self.clarification = try c.decodeIfPresent(ClarificationRequest.self, forKey: .clarification)
        }

        init(summary: String, templates: [TemplateSpec], critique: Critique, clarification: ClarificationRequest?) {
            self.summary = summary
            self.templates = templates
            self.critique = critique
            self.clarification = clarification
        }
    }

    @MainActor
    func reviewPlan(rawText: String, profile: UserProfile?) async throws -> PlanReview {
        let system = reviewSystemPrompt(profile: profile)
        let user = "User's pasted plan:\n\n\(rawText)"
        let schema = reviewSchema()

        let ai = AIService()
        let raw = try await ai.chatJSON(systemPrompt: system, userPrompt: user, schema: schema)
        guard let data = raw.data(using: .utf8) else { throw ModError.decode }
        let decoded = try JSONDecoder().decode(PlanReview.self, from: data)
        guard decoded.hasContent || decoded.hasClarification else {
            throw ModError.emptyResponse
        }
        return decoded
    }

    // MARK: - Generate

    @MainActor
    func generate(
        routine: Routine?,
        userPrompt: String,
        profile: UserProfile? = nil
    ) async throws -> GenerateResponse {
        let system = systemPrompt(routinePresent: routine != nil, profile: profile)
        let user = userMessage(routine: routine, prompt: userPrompt, profile: profile)
        let schema = responseSchema()

        let ai = AIService()
        let raw = try await ai.chatJSON(systemPrompt: system, userPrompt: user, schema: schema)
        guard let data = raw.data(using: .utf8) else { throw ModError.decode }
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard !decoded.isEmpty else { throw ModError.emptyResponse }
        return decoded
    }

    /// Apply edits to a routine, returning the modified copy.
    func apply(_ edits: [EditOp], to routine: Routine) -> Routine {
        var working = routine
        var exs = working.exercises
        for edit in edits {
            switch edit.op {
            case "swap":
                if let target = edit.target, let replacement = edit.replacement,
                   let idx = exs.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(target) }) {
                    exs[idx].name = replacement
                    if let mg = edit.muscleGroup, !mg.isEmpty {
                        exs[idx].muscleGroup = mg
                    }
                }
            case "add":
                if let replacement = edit.replacement {
                    let new = RoutineExercise(
                        name: replacement,
                        sets: edit.sets ?? 3,
                        reps: edit.reps ?? "8-12",
                        muscleGroup: edit.muscleGroup ?? ""
                    )
                    let pos = max(0, min(edit.position ?? exs.count, exs.count))
                    exs.insert(new, at: pos)
                }
            case "remove":
                if let target = edit.target {
                    exs.removeAll { $0.name.localizedCaseInsensitiveContains(target) }
                }
            case "change_sets":
                if let target = edit.target, let sets = edit.sets,
                   let idx = exs.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(target) }) {
                    exs[idx].sets = sets
                }
            case "change_reps":
                if let target = edit.target, let reps = edit.reps,
                   let idx = exs.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(target) }) {
                    exs[idx].reps = reps
                }
            default:
                continue
            }
        }
        working.exercises = exs
        working.updatedAt = Date()
        return working
    }

    // MARK: - Prompt construction

    private func systemPrompt(routinePresent: Bool, profile: UserProfile?) -> String {
        let profileBlock: String = {
            guard let p = profile else { return "" }
            var lines: [String] = ["User profile:"]
            if !p.primaryGoal.isEmpty { lines.append("  - Goal: \(p.primaryGoal)") }
            if !p.trainingExperience.isEmpty { lines.append("  - Experience: \(p.trainingExperience)") }
            if !p.trainingLocation.isEmpty { lines.append("  - Trains at: \(p.trainingLocation)") }
            if p.workoutsPerWeek > 0 { lines.append("  - Workouts/week: \(p.workoutsPerWeek)") }
            if !p.weakPoints.isEmpty { lines.append("  - Weak points: \(p.weakPoints.joined(separator: ", "))") }
            return lines.joined(separator: "\n")
        }()

        let editsBlock = """
        - "edits" array (modify the existing template). Each entry:
          - op: "swap" | "add" | "remove" | "change_sets" | "change_reps"
          - target: exercise name to act on (for swap/remove/change_*)
          - replacement: new exercise name (for swap/add)
          - muscleGroup: e.g. "Chest", "Back" (optional)
          - position: 0-based index for add (optional)
          - sets: integer (for add/change_sets)
          - reps: string like "8-12", "5", "AMRAP" (for add/change_reps)
          - reason: one short clause
        """

        let createBlock = """
        - "newTemplates" array (build templates from scratch). Each entry:
          - name: e.g. "Upper Body"
          - icon: one of "dumbbell.fill" | "figure.strengthtraining.traditional" | "figure.run" | "figure.core.training" | "flame.fill" | "heart.fill" | "bolt.fill"
          - defaultRestSeconds: int 60–180
          - exercises: array of {name, sets, reps, muscleGroup}
          - reason: one short clause
        Use realistic exercise names ("Bench Press (Barbell)", "Lat Pulldown",
        "Romanian Deadlift"). Pick exercises that match the user's training
        location (gym vs. home) — never prescribe barbell work for home unless
        the user explicitly mentioned having a barbell.
        """

        let clarifyBlock = """
        - "clarification": { "questions": [...] } when the request is genuinely
        ambiguous (e.g. user says "make me a workout" without specifying split,
        days, equipment, or goal). Each question is short, specific, and
        answerable in one sentence. Limit to 1-3 questions. ONLY use this when
        you truly can't proceed; if the prompt is reasonable, fill the
        appropriate field instead and infer sensible defaults from the user's
        profile above.
        """

        let modeHint = routinePresent
            ? "If the user wants to TWEAK the existing template, fill `edits`. If they want NEW templates, fill `newTemplates`. If you can't tell, fill `clarification`. Fill exactly one of these. Never fill multiple."
            : "Fill `newTemplates`, or `clarification` if the prompt is ambiguous. Never fill `edits` since there is no existing template."

        var pieces: [String] = []
        if !profileBlock.isEmpty { pieces.append(profileBlock) }
        pieces.append("""
        You are FitAI's workout coach. The user wants help with their workout
        templates. Output a strict JSON object with these top-level keys:
          - "summary": one short sentence describing what you did or what's missing.
          - "edits": array (may be empty).
          - "newTemplates": array (may be empty).
          - "clarification": null OR an object with "questions".

        \(editsBlock)

        \(createBlock)

        \(clarifyBlock)

        \(modeHint)

        STYLE: Never use em dashes (—) in any field. Use commas, periods, or parentheses instead. Hyphens (-) in compound words like "AI-generated" are fine.
        """)
        return pieces.joined(separator: "\n\n")
    }

    private func userMessage(routine: Routine?, prompt: String, profile: UserProfile?) -> String {
        var lines: [String] = []
        if let r = routine {
            lines.append("Current template:")
            lines.append("  Name: \(r.name)")
            lines.append("  Default rest: \(r.defaultRestSeconds)s")
            lines.append("  Exercises:")
            for (i, ex) in r.exercises.enumerated() {
                lines.append("    \(i). \(ex.name) — \(ex.sets) sets × \(ex.reps) (\(ex.muscleGroup))")
            }
        } else {
            lines.append("(No existing template — the user wants new ones built from scratch.)")
        }
        lines.append("")
        lines.append("User request: \(prompt)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Review-mode prompt + schema

    private func reviewSystemPrompt(profile: UserProfile?) -> String {
        let profileBlock: String = {
            guard let p = profile else { return "" }
            var lines: [String] = ["User profile:"]
            if !p.primaryGoal.isEmpty { lines.append("  - Goal: \(p.primaryGoal)") }
            if !p.trainingExperience.isEmpty { lines.append("  - Experience: \(p.trainingExperience)") }
            if !p.trainingLocation.isEmpty { lines.append("  - Trains at: \(p.trainingLocation)") }
            if p.workoutsPerWeek > 0 { lines.append("  - Workouts/week: \(p.workoutsPerWeek)") }
            if !p.weakPoints.isEmpty { lines.append("  - Weak points: \(p.weakPoints.joined(separator: ", "))") }
            return lines.joined(separator: "\n")
        }()

        let mainPrompt = """
        You are FitAI's workout coach. The user is going to paste their existing
        workout program in any format — bullet points, paragraphs, abbreviations.
        Your job:

        1. Parse it into one or more `templates`. Each template = one training
        session (e.g. one day of a split). Convert exercise abbreviations to
        full names ("BB bench" → "Bench Press (Barbell)", "RDL" → "Romanian
        Deadlift"). Keep their sets/reps as written when present.

        2. Critique the program honestly. Fill `critique` with:
          - "strengths": 1–3 short bullets on what's good.
          - "weaknesses": 1–3 short bullets on what's missing or imbalanced
            (under-trained muscle groups, poor exercise selection, junk
            volume, no progression scheme, etc.).
          - "suggestions": 1–3 concrete, actionable improvements.

        3. If the user's input is too vague to parse (e.g. just "I do PPL"),
        return `clarification` with 1–3 specific questions instead of guessing.

        Each template:
          - name (e.g. "Push Day")
          - icon (one of "dumbbell.fill" | "figure.strengthtraining.traditional" | "figure.run" | "figure.core.training" | "flame.fill" | "heart.fill" | "bolt.fill")
          - defaultRestSeconds (60–180)
          - exercises: array of {name, sets, reps, muscleGroup}
          - reason: optional one-clause note (e.g. "added missing direct biceps work")

        Output strict JSON. No prose, no markdown.

        STYLE: Never use em dashes (—) in any string field (name, reason, suggestions, summary, etc.). Use commas, periods, or parentheses instead. Hyphens (-) in compound words like "AI-generated" are fine.
        """

        return profileBlock.isEmpty ? mainPrompt : "\(profileBlock)\n\n\(mainPrompt)"
    }

    private func reviewSchema() -> [String: AnyCodable] {
        let exerciseSpec: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "sets": ["type": "integer"],
                "reps": ["type": "string"],
                "muscleGroup": ["type": "string"]
            ],
            "required": ["name", "sets", "reps", "muscleGroup"]
        ]
        let templateSpec: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "icon": ["type": "string"],
                "defaultRestSeconds": ["type": "integer"],
                "exercises": ["type": "array", "items": exerciseSpec],
                "reason": ["type": "string"]
            ],
            "required": ["name", "exercises"]
        ]
        let critique: [String: Any] = [
            "type": "object",
            "properties": [
                "strengths": ["type": "array", "items": ["type": "string"]],
                "weaknesses": ["type": "array", "items": ["type": "string"]],
                "suggestions": ["type": "array", "items": ["type": "string"]]
            ]
        ]
        let clarification: [String: Any] = [
            "type": "object",
            "properties": [
                "questions": ["type": "array", "items": ["type": "string"]]
            ]
        ]
        return [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "summary": ["type": "string"],
                "templates": ["type": "array", "items": templateSpec],
                "critique": critique,
                "clarification": clarification
            ]),
            "required": AnyCodable(["summary"])
        ]
    }

    // MARK: - Response schema (Gemini structured output)

    private func responseSchema() -> [String: AnyCodable] {
        let exerciseSpec: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "sets": ["type": "integer"],
                "reps": ["type": "string"],
                "muscleGroup": ["type": "string"]
            ],
            "required": ["name", "sets", "reps", "muscleGroup"]
        ]

        let templateSpec: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "icon": ["type": "string"],
                "defaultRestSeconds": ["type": "integer"],
                "exercises": [
                    "type": "array",
                    "items": exerciseSpec
                ],
                "reason": ["type": "string"]
            ],
            "required": ["name", "exercises"]
        ]

        let editOp: [String: Any] = [
            "type": "object",
            "properties": [
                "op": ["type": "string"],
                "target": ["type": "string"],
                "replacement": ["type": "string"],
                "muscleGroup": ["type": "string"],
                "position": ["type": "integer"],
                "sets": ["type": "integer"],
                "reps": ["type": "string"],
                "reason": ["type": "string"]
            ],
            "required": ["op"]
        ]

        let clarification: [String: Any] = [
            "type": "object",
            "properties": [
                "questions": [
                    "type": "array",
                    "items": ["type": "string"]
                ]
            ]
        ]

        return [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "summary": ["type": "string"],
                "edits": [
                    "type": "array",
                    "items": editOp
                ],
                "newTemplates": [
                    "type": "array",
                    "items": templateSpec
                ],
                "clarification": clarification
            ]),
            "required": AnyCodable(["summary"])
        ]
    }
}
