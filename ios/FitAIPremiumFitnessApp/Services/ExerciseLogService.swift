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
}
