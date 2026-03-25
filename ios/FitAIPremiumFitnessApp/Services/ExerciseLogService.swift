import Foundation

class ExerciseLogService {
    static let shared = ExerciseLogService()
    private let key = "exerciseLogs"

    func saveLog(_ log: ExerciseLog) {
        var all = loadAll()
        all.append(log)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
