import Foundation

/// Picks rest time based on movement type, rep range, and load.
///
/// Resolution at the call site is layered: caller checks for a user
/// override first; this service only runs when there's no saved value
/// to honor. Output is rounded to the keypad presets so the surfaced
/// number always matches what users see in the editor (30/45/60/75/90/
/// 120/180/240).
enum RestRecommender {
    /// Compute rest for the set just completed. `completedWeight` is the
    /// weight the user actually logged; if it's ≥1.05× their recent
    /// average for this lift the recommender bumps one tier (the "heavy
    /// squat" case the rest rework was built for).
    static func recommend(
        exerciseName: String,
        repsString: String,
        completedWeight: Double = 0,
        recentAverageWeight: Double = 0
    ) -> Int {
        let category = ExerciseDatabase.shared.category(for: exerciseName)
        let range = RepRange.parse(repsString)
        let base = baseline(category: category, range: range)

        guard isHeavySet(completedWeight: completedWeight, recentAverage: recentAverageWeight) else {
            return base
        }
        let bumped = base + (category == .heavyCompound ? 60 : 30)
        return roundedToPreset(bumped)
    }

    /// Baseline without load awareness — used by the editor and any
    /// pre-session preview where we don't yet know the logged weight.
    static func suggestedBaseline(
        exerciseName: String,
        repsString: String
    ) -> Int {
        let category = ExerciseDatabase.shared.category(for: exerciseName)
        let range = RepRange.parse(repsString)
        return baseline(category: category, range: range)
    }

    // MARK: - Internals

    /// Movement type × rep range. Values picked to align with the keypad
    /// presets so we never surface odd numbers. Unknown category defaults
    /// to the compound row — it's the safest middle ground and matches
    /// the existing 90s default for moderate-rep work.
    private static func baseline(category: ExerciseCategory, range: RepRange) -> Int {
        switch (category, range) {
        case (.heavyCompound, .strength): return 240
        case (.heavyCompound, .hypertrophy): return 180
        case (.heavyCompound, .endurance): return 90
        case (.compound, .strength), (.unknown, .strength): return 180
        case (.compound, .hypertrophy), (.unknown, .hypertrophy): return 120
        case (.compound, .endurance), (.unknown, .endurance): return 60
        case (.isolation, .strength): return 90
        case (.isolation, .hypertrophy): return 60
        case (.isolation, .endurance): return 45
        }
    }

    private static func isHeavySet(completedWeight: Double, recentAverage: Double) -> Bool {
        guard completedWeight > 0, recentAverage > 0 else { return false }
        return completedWeight >= recentAverage * 1.05
    }

    private static let presets: [Int] = [30, 45, 60, 75, 90, 120, 180, 240, 300]

    private static func roundedToPreset(_ seconds: Int) -> Int {
        // Snap up to the next preset so a +60s bump never silently
        // disappears into the same bucket.
        for preset in presets where preset >= seconds { return preset }
        return presets.last ?? seconds
    }
}

/// Coarse rep-range bucket. We don't need surgical precision — the rest
/// table only has three columns.
nonisolated enum RepRange: Sendable {
    case strength    // ≤5 reps
    case hypertrophy // 6–11 reps
    case endurance   // ≥12 reps

    /// Parse the lower bound of a reps string. "5" → 5, "8-12" → 8,
    /// "AMRAP" / "max" → hypertrophy fallback. Time-based reps ("30s")
    /// also fall through to hypertrophy — rest length for isometrics is
    /// dominated by the duration of the hold itself, so the table's
    /// middle value is a safer default than `endurance`.
    static func parse(_ reps: String) -> RepRange {
        let trimmed = reps.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return .hypertrophy }

        // Time-based or non-numeric → hypertrophy fallback.
        if trimmed.contains("min") || trimmed.contains("sec") || trimmed.hasSuffix("s") {
            return .hypertrophy
        }

        let lower: Int? = {
            if let hyphenIdx = trimmed.firstIndex(where: { $0 == "-" || $0 == "–" }) {
                return Int(trimmed[..<hyphenIdx])
            }
            return Int(trimmed)
        }()

        guard let n = lower else { return .hypertrophy }
        if n <= 5 { return .strength }
        if n >= 12 { return .endurance }
        return .hypertrophy
    }
}
