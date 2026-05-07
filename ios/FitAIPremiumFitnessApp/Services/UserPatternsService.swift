import Foundation

/// Heuristic-only personalization layer. Pulls patterns out of the user's
/// `ExerciseLogService` history and surfaces them as quick predictions for
/// the voice + photo logging flows.
///
/// No ML — just statistics over the rolling history. The point is to
/// pre-fill confident defaults so the user rarely has to type / speak a
/// number we already could have guessed: rep counts, working weights,
/// favorite exercises per muscle group, inferred bar weight, and so on.
nonisolated final class UserPatternsService: Sendable {
    static let shared = UserPatternsService()

    private let logService = ExerciseLogService.shared
    /// How many recent sessions to look back for "what did they do at this
    /// weight" style predictions. Older data drifts as the user gets stronger.
    private let lookbackSessions: Int = 5

    private init() {}

    // MARK: - Reps prediction

    /// Best guess for how many reps the user is about to do. Used as the
    /// default in photo-based set logging. Returns nil if no usable history.
    func expectedReps(exercise: String, weight: Double, setIndex: Int) -> Int? {
        let history = logService.history(for: exercise)
        let recent = history.logs
            .sorted { $0.date > $1.date }
            .prefix(lookbackSessions)

        // Match sets at this weight ± 5% so a 185 lb workout weighs in
        // when the photo says 180 (e.g., the user grabs 2.5s instead).
        let tolerance = max(weight * 0.05, 2.5)
        let matchingReps = recent
            .flatMap(\.sets)
            .filter { $0.countsTowardVolume }
            .filter { abs($0.weight - weight) <= tolerance }
            .map(\.reps)

        if let median = median(of: matchingReps) {
            return median
        }

        // No match at this weight — fall back to most-recent session's
        // reps for the same set position. Better than nothing.
        if let lastSession = history.lastSession,
           let rowAtSetIdx = lastSession.sets[safe: setIndex],
           rowAtSetIdx.isCompleted {
            return rowAtSetIdx.reps > 0 ? rowAtSetIdx.reps : nil
        }
        return nil
    }

    /// Plausible rep range for an exercise — used by the voice parser to
    /// disambiguate suspicious numbers. If the user's bench is always
    /// 4–8 reps, "fourteen" should trigger a re-confirm.
    func typicalRepRange(exercise: String) -> ClosedRange<Int>? {
        let history = logService.history(for: exercise)
        let reps = history.logs
            .flatMap(\.sets)
            .filter { $0.countsTowardVolume && $0.reps > 0 }
            .map(\.reps)
        guard reps.count >= 5 else { return nil }
        let sorted = reps.sorted()
        // 10th–90th percentile. Trims outliers without throwing them out.
        let lo = sorted[max(0, sorted.count / 10)]
        let hi = sorted[min(sorted.count - 1, (sorted.count * 9) / 10)]
        return lo...max(hi, lo)
    }

    // MARK: - Weight prediction

    /// Predicted working weight for a given set position. Pulls last
    /// session's value, with an opportunistic +2.5 lb / +1.25 kg progressive-
    /// overload bump if the user crushed last session (all sets completed
    /// at the high end of their rep range).
    func expectedWeight(exercise: String, setIndex: Int, usesMetric: Bool) -> Double? {
        let history = logService.history(for: exercise)
        guard let lastSession = history.lastSession else { return nil }
        guard let row = lastSession.sets[safe: setIndex],
              row.weight > 0 else { return nil }

        let allCompletedHighEnd = lastSession.sets
            .filter(\.countsTowardVolume)
            .allSatisfy { $0.reps >= (typicalRepRange(exercise: exercise)?.upperBound ?? Int.max) }

        if allCompletedHighEnd {
            return row.weight + (usesMetric ? 1.25 : 2.5)
        }
        return row.weight
    }

    // MARK: - Exercise affinity

    /// Most-used exercises in a given muscle group, sorted by recency × frequency.
    /// Used to bias photo scene-detection ties (if AI sees a generic bench
    /// setup and the user has done flat bench 30× and incline 2×, prefer flat).
    func favoriteExercises(muscleGroup: String, limit: Int = 5) -> [String] {
        let allLogs = logService.loadAll()
        let byExercise = Dictionary(grouping: allLogs.filter { log in
            log.muscleGroup.localizedCaseInsensitiveContains(muscleGroup) ||
            muscleGroup.isEmpty
        }, by: \.exerciseName)

        let scored = byExercise.map { name, logs -> (String, Double) in
            let frequency = Double(logs.count)
            let mostRecent = logs.map(\.date).max() ?? .distantPast
            let daysAgo = max(0, Date().timeIntervalSince(mostRecent) / 86400)
            // Heavier weight on recency — old habits decay.
            let recencyDecay = exp(-daysAgo / 21)
            return (name, frequency * recencyDecay)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Bar weight inference

    /// User's most likely barbell weight, inferred from history. The AI
    /// vision call asks for plates per side and bar weight separately, but
    /// when the bar weight is missing we fall back to this. Olympic = 45 lb /
    /// 20 kg; some gyms have lighter "training" bars.
    func inferredBarWeight(usesMetric: Bool) -> Double {
        // For now, default. Later: scan past barbell logs and find the
        // common (logged_total - 2 × sum_plates) value.
        return usesMetric ? 20.0 : 45.0
    }

    // MARK: - Schedule patterns

    /// Day-of-week → most-frequent muscle-group slot. Used by the Workouts
    /// hub to suggest "you usually do Push on Monday" without needing a
    /// formal schedule.
    func likelyMuscleGroupForToday() -> String? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let allLogs = logService.loadAll()
        let dayLogs = allLogs.filter {
            Calendar.current.component(.weekday, from: $0.date) == weekday
        }
        let counts = Dictionary(grouping: dayLogs, by: \.muscleGroup)
            .mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Helpers

    private func median(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
