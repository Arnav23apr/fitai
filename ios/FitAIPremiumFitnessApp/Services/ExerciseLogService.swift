import Foundation

class ExerciseLogService {
    static let shared = ExerciseLogService()
    private let key = "exerciseLogs"

    private let maxEntries = 500

    func saveLog(_ log: ExerciseLog) {
        var all = loadAll()
        all.append(log)
        if all.count > maxEntries {
            all = Array(all.suffix(maxEntries))
        }
        replaceAll(all)
    }

    func replaceAll(_ logs: [ExerciseLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Update an existing log in-place. Matches by id. No-op if not found.
    func updateLog(_ updated: ExerciseLog) {
        var all = loadAll()
        guard let idx = all.firstIndex(where: { $0.id == updated.id }) else { return }
        all[idx] = updated
        replaceAll(all)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func loadAll() -> [ExerciseLog] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let logs = try? JSONDecoder().decode([ExerciseLog].self, from: data) else {
            return []
        }
        return logs
    }

    func history(for exerciseName: String) -> ExerciseHistory {
        let logs = loadAll().filter { $0.exerciseName == exerciseName }
        return ExerciseHistory(exerciseName: exerciseName, logs: logs)
    }

    func lastSession(for exerciseName: String) -> ExerciseLog? {
        history(for: exerciseName).lastSession
    }

    /// Average top-set weight over the most recent `sessions` logs. Used by
    /// `RestRecommender` to decide whether the current set is "heavy" and
    /// deserves a longer rest. Returns 0 when there's no history (which
    /// disables the heavy bump — first session gets the baseline rest).
    func recentTopSetAverage(for exerciseName: String, sessions: Int = 5) -> Double {
        let recent = history(for: exerciseName).logs
            .sorted { $0.date > $1.date }
            .prefix(sessions)
            .map(\.bestSetWeight)
            .filter { $0 > 0 }
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0, +) / Double(recent.count)
    }

    func personalBestWeight(for exerciseName: String) -> Double {
        history(for: exerciseName).personalBestWeight
    }

    func personalBestReps(for exerciseName: String) -> Int {
        history(for: exerciseName).personalBestReps
    }

    func checkForNewPR(exerciseName: String, weight: Double, reps: Int) -> Bool {
        let best = personalBestWeight(for: exerciseName)
        return weight > best && best > 0
    }

    /// Detect every kind of PR a single set might have hit. Caller
    /// passes the set in question; this compares against history that
    /// excludes the current session (so a set isn't its own PR baseline).
    /// Returns an empty set if the lifter has no prior history or this
    /// is the first time touching the exercise.
    ///
    /// `excludingLogId` is the in-progress session log; we skip it when
    /// building the comparison baseline so the lifter sees PRs land on
    /// the exact set that broke their record, not retroactively.
    func detectPRs(
        exerciseName: String,
        weight: Double,
        reps: Int,
        excludingLogId: String? = nil
    ) -> Set<PRType> {
        let logs = loadAll().filter {
            $0.exerciseName == exerciseName && $0.id != excludingLogId
        }
        guard !logs.isEmpty else { return [] }
        let history = ExerciseHistory(exerciseName: exerciseName, logs: logs)

        var prs: Set<PRType> = []

        if weight > 0, weight > history.personalBestWeight {
            prs.insert(.weight)
        }
        if weight > 0, reps > 0 {
            let priorBestReps = history.personalBestReps(at: weight)
            if priorBestReps > 0, reps > priorBestReps {
                prs.insert(.reps)
            }
        }
        let estOneRM = StrengthMath.estimatedOneRM(weight: weight, reps: reps)
        if estOneRM > 0, estOneRM > history.personalBestEstimatedOneRM * 1.005 {
            // Tiny epsilon so floating-point ties don't false-positive.
            prs.insert(.estimatedOneRM)
        }

        return prs
    }
}

/// The four kinds of personal record we surface. A single set can
/// trigger more than one (e.g. heaviest weight is also a new est-1RM).
nonisolated enum PRType: String, Codable, Sendable, CaseIterable {
    case weight
    case reps
    case volume
    case estimatedOneRM

    var label: String {
        switch self {
        case .weight: return "Weight PR"
        case .reps: return "Rep PR"
        case .volume: return "Volume PR"
        case .estimatedOneRM: return "1RM PR"
        }
    }

    var shortLabel: String {
        switch self {
        case .weight: return "WT"
        case .reps: return "REPS"
        case .volume: return "VOL"
        case .estimatedOneRM: return "1RM"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .reps: return "repeat"
        case .volume: return "chart.bar.fill"
        case .estimatedOneRM: return "flame.fill"
        }
    }
}
