import Foundation

/// Plan tab top-level segmented mode: AI-generated daily plan vs user
/// routines. Default is chosen at first-run from training experience —
/// beginners see the AI plan; intermediate/advanced default to Routines
/// so they can log Hevy-style without scrolling past the AI prescription.
nonisolated enum PlanMode: String, CaseIterable, Sendable {
    case today
    case routines

    static func defaultFor(experience: String) -> PlanMode {
        let lower = experience.lowercased()
        if lower.contains("intermediate") || lower.contains("advanced") {
            return .routines
        }
        return .today
    }
}

/// User-created workout template (Hevy/Strong-style). Reusable: pick from
/// the Routines tab and start. Persisted locally in UserDefaults; cloud sync
/// is intentionally deferred (out of scope for this pass).
nonisolated struct Routine: Identifiable, Codable, Sendable {
    let id: String
    var name: String
    var icon: String
    var exercises: [RoutineExercise]
    /// Per-routine default rest in seconds. A `RoutineExercise` may override
    /// it. Default 90s based on research norms (Hevy's default is 2:00,
    /// Strong's is 2:00 — 90s sits in the strength-hypertrophy sweet spot
    /// the AI plan also generates against).
    var defaultRestSeconds: Int
    /// Folder this routine belongs to. nil = uncategorized (top-level).
    /// Hevy/Strong both use freeform folder names ("Hypertrophy block 1",
    /// "Cut phase"); we follow the same string-based model so users can
    /// rename folders without an id-based migration. Optional for
    /// backwards compatibility with existing persisted blobs.
    var folder: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "dumbbell.fill",
        exercises: [RoutineExercise] = [],
        defaultRestSeconds: Int = 90,
        folder: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.exercises = exercises
        self.defaultRestSeconds = defaultRestSeconds
        self.folder = folder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A single exercise within a routine, with its sets/reps/rest config. Mirrors
/// `Exercise` but stays Codable + locally editable. We convert to `Exercise`
/// at start-time so the existing WorkoutSessionManager flow works unchanged.
nonisolated struct RoutineExercise: Identifiable, Codable, Sendable {
    let id: String
    var name: String
    var sets: Int
    var reps: String
    var muscleGroup: String
    /// Per-exercise rest override in seconds. nil → fall back to the
    /// routine's `defaultRestSeconds`.
    var restSecondsOverride: Int?
    /// Optional notes (form cues, weights to try). Surfaced inline.
    var notes: String
    /// Superset group label (1, 2, 3, …). Exercises sharing a group are
    /// performed back-to-back with no rest between, then rest once after
    /// the round. nil = solo exercise (default).
    var supersetGroup: Int?
    /// Planned RPE / RIR (Rate of Perceived Exertion / Reps in Reserve).
    /// Range 6–10 (RPE) — Hevy/Strong both surface this as "@8" etc.
    /// nil = no target set.
    var targetRPE: Int?

    init(
        id: String = UUID().uuidString,
        name: String,
        sets: Int = 3,
        reps: String = "8-12",
        muscleGroup: String = "",
        restSecondsOverride: Int? = nil,
        notes: String = "",
        supersetGroup: Int? = nil,
        targetRPE: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.muscleGroup = muscleGroup
        self.restSecondsOverride = restSecondsOverride
        self.notes = notes
        self.supersetGroup = supersetGroup
        self.targetRPE = targetRPE
    }

    func resolvedRest(in routine: Routine) -> Int {
        restSecondsOverride ?? routine.defaultRestSeconds
    }
}

extension RoutineExercise {
    /// Bridge from the AI-plan `Exercise` shape so the AI plan can flow
    /// through ActiveSessionView (Strong-style logger) — same path templates
    /// take. Drops AI-only fields like suggestedWeights since they're
    /// already used by SessionExercise's previous-performance prefill.
    init(from exercise: Exercise) {
        self.init(
            id: exercise.id,
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            muscleGroup: exercise.muscleGroup
        )
    }
}

extension Routine {
    /// Build a `Routine` from a `WorkoutDay` so the AI-plan tap-to-start
    /// flow can use the same ActiveSessionView path as templates.
    init(from workout: WorkoutDay) {
        self.init(
            id: workout.id,
            name: workout.name,
            icon: workout.icon.isEmpty ? "dumbbell.fill" : workout.icon,
            exercises: workout.exercises.map(RoutineExercise.init(from:)),
            defaultRestSeconds: 90
        )
    }

    /// Build a `WorkoutDay` from the routine so the existing detail sheet
    /// + session manager can run it without bespoke plumbing. The dayLabel
    /// uses the routine name so resume/persistence sees the same identity.
    func toWorkoutDay() -> WorkoutDay {
        WorkoutDay(
            id: id,
            dayLabel: "ROUTINE",
            name: name,
            focusAreas: focusAreasSummary,
            icon: icon,
            isRestDay: false,
            exercises: exercises.map { ex in
                Exercise(
                    id: ex.id,
                    name: ex.name,
                    sets: ex.sets,
                    reps: ex.reps,
                    muscleGroup: ex.muscleGroup
                )
            },
            isWeakPointFocus: false
        )
    }

    private var focusAreasSummary: [String] {
        let groups = Array(Set(exercises.map(\.muscleGroup).filter { !$0.isEmpty }))
        return Array(groups.prefix(3))
    }
}
