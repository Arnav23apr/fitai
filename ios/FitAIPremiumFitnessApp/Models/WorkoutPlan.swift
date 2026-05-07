import Foundation

nonisolated struct WorkoutDay: Identifiable, Sendable {
    let id: String
    let dayLabel: String
    let name: String
    let focusAreas: [String]
    let icon: String
    let isRestDay: Bool
    let exercises: [Exercise]
    let isWeakPointFocus: Bool

    init(id: String = UUID().uuidString, dayLabel: String, name: String, focusAreas: [String], icon: String, isRestDay: Bool = false, exercises: [Exercise] = [], isWeakPointFocus: Bool = false) {
        self.id = id
        self.dayLabel = dayLabel
        self.name = name
        self.focusAreas = focusAreas
        self.icon = icon
        self.isRestDay = isRestDay
        self.exercises = exercises
        self.isWeakPointFocus = isWeakPointFocus
    }
}

nonisolated struct Exercise: Identifiable, Sendable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
    let muscleGroup: String
    let suggestedWeights: [Double]
    let suggestedReps: [Int]

    var demoInfo: ExerciseDemoInfo {
        ExerciseDatabase.shared.info(for: name)
    }

    init(id: String = UUID().uuidString, name: String, sets: Int, reps: String, muscleGroup: String, suggestedWeights: [Double] = [], suggestedReps: [Int] = []) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.muscleGroup = muscleGroup
        self.suggestedWeights = suggestedWeights
        self.suggestedReps = suggestedReps
    }
}

nonisolated enum ExerciseTrackingMode: Sendable, Equatable {
    case weighted    // weight + reps (default for strength)
    case bodyweight  // reps + bodyweight toggle
    case timed       // duration in seconds (cardio, mobility, holds)
    case repsOnly    // reps only, no weight (stretches with rep counts)
}

extension Exercise {
    /// Detected tracking mode for this exercise. Determines whether the
    /// logging UI shows weight, reps, duration, or some combination.
    ///
    /// Order matters: explicit per-exercise overrides → time-string detection →
    /// cardio bucket → mobility/stretch heuristic → bodyweight detector → weighted.
    var trackingMode: ExerciseTrackingMode {
        let r = reps.lowercased().trimmingCharacters(in: .whitespaces)
        let group = muscleGroup.lowercased()
        let n = name.lowercased()

        // 1. Explicit overrides — exercises whose names trip the heuristics
        // for the wrong reason. "Walking Lunges" used to match the "walk"
        // substring and get classified as timed; that bug surfaced in the
        // logger as a MIN:SEC field for what is clearly a rep-counted move.
        if Self.repBasedExerciseOverrides.contains(n) { return .bodyweight }
        // Inverse override — exercises that should always be timed even
        // when the plan generator forgets the "s"/"sec" suffix on reps.
        if Self.alwaysTimedExerciseOverrides.contains(n) { return .timed }

        // 2. Time-based reps strings: "10min", "20min", "30s", "60s/side", "90sec"
        let isTimeReps = r.contains("min") || r.contains("sec") ||
            r.range(of: #"^\d+s(\s*/.+)?$"#, options: .regularExpression) != nil
        if isTimeReps { return .timed }

        // 3. Cardio is always timed (covers walking, running, cycling,
        // rowing, ellipticals — the muscle-group bucket is the source of
        // truth here, not the name).
        if group == "cardio" { return .timed }

        // 4. Mobility / recovery / stretches / holds. Note: "walk" is NOT
        // in this list — it falsely matched Walking Lunges, Farmer's Walk,
        // Walking Plank, etc. Those are handled by the override list above
        // or by the bodyweight detector below; cardio walks are caught by
        // the cardio bucket.
        let isMobility = n.contains("stretch") || n.contains("foam") || n.contains("rolling") ||
            n.contains("mobility") || n.contains("yoga") ||
            n.contains("cat-cow") || n.contains("cat cow") || n.contains("hold")
        if isMobility {
            return Int(r) != nil ? .repsOnly : .timed
        }

        if BodyweightDetector.isBodyweightExercise(name) {
            return .bodyweight
        }

        return .weighted
    }

    /// Lowercased exercise names that must always be tracked as bodyweight
    /// reps (not time, not weighted) — these are the names that the
    /// substring heuristic above gets wrong. Add cautiously; one entry per
    /// real bug, not speculative additions.
    private static let repBasedExerciseOverrides: Set<String> = [
        "walking lunges",
        "walking lunge",
        "walking dumbbell lunges",
        "walking db lunges",
        "reverse walking lunges",
        "walking push-up",
        "walking push up",
        "walking plank",
    ]

    /// Lowercased exercise names that must always be tracked as duration
    /// (not bodyweight reps), even when the plan-generator sends a
    /// number-only reps string like "30" instead of "30s". These are
    /// universally timed in practice; very rare to see a plain rep target.
    private static let alwaysTimedExerciseOverrides: Set<String> = [
        "plank",
        "planks",
        "side plank",
        "side planks",
        "wall sit",
        "dead hang",
        "elbow plank",
        "forearm plank",
    ]

    /// For timed exercises, target duration in seconds parsed from the reps field.
    /// "10min" → 600, "60s/side" → 60, "30s" → 30, "90sec" → 90.
    var targetDurationSeconds: Int {
        let s = reps.lowercased().replacingOccurrences(of: " ", with: "")
        if let mins = Self.numericPrefix(in: s, before: "min") { return mins * 60 }
        if let secs = Self.numericPrefix(in: s, before: "sec") { return secs }
        if let secs = Self.numericPrefix(in: s, before: "s") { return secs }
        return 0
    }

    private static func numericPrefix(in s: String, before suffix: String) -> Int? {
        guard let range = s.range(of: suffix) else { return nil }
        let prefix = s[..<range.lowerBound]
        return Int(prefix)
    }
}

nonisolated struct ExerciseDemoInfo: Sendable {
    let name: String
    let instructions: [String]
    let tips: [String]
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let videoURL: String
    let thumbnailURL: String
    let frames: [String]

    var hasMedia: Bool { !videoURL.isEmpty || !thumbnailURL.isEmpty || !frames.isEmpty }

    init(name: String, instructions: [String], tips: [String], primaryMuscles: [String], secondaryMuscles: [String], videoURL: String, thumbnailURL: String, frames: [String] = []) {
        self.name = name
        self.instructions = instructions
        self.tips = tips
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.frames = frames
    }

    static let empty = ExerciseDemoInfo(name: "", instructions: [], tips: [], primaryMuscles: [], secondaryMuscles: [], videoURL: "", thumbnailURL: "")
}

nonisolated struct WorkoutLog: Codable, Identifiable, Sendable {
    let id: String
    let date: Date
    let dayName: String
    let exercisesCompleted: Int
    let totalExercises: Int
    let durationMinutes: Int
    let completedExerciseNames: [String]

    init(id: String = UUID().uuidString, date: Date = Date(), dayName: String, exercisesCompleted: Int, totalExercises: Int, durationMinutes: Int, completedExerciseNames: [String] = []) {
        self.id = id
        self.date = date
        self.dayName = dayName
        self.exercisesCompleted = exercisesCompleted
        self.totalExercises = totalExercises
        self.durationMinutes = durationMinutes
        self.completedExerciseNames = completedExerciseNames
    }
}
