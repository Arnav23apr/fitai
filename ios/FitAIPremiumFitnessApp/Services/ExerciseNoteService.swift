import Foundation

/// Strong-style pinned exercise notes. A pinned note is a string that
/// persists per exercise *name*, so every future session of "Bench
/// Press" will surface it on top of the exercise card. Used for things
/// like "use foot plate at hole 4" or "wrist wraps for set 3" that the
/// lifter wants on every session, not just one.
///
/// Pinned notes are distinct from per-session set notes (`SetLog.note`)
/// and from in-routine planning notes (`RoutineExercise.notes`); this
/// service owns the per-exercise persistent layer.
class ExerciseNoteService {
    static let shared = ExerciseNoteService()
    private let key = "exerciseNotes_pinned_v1"

    /// Returns the pinned note for an exercise name, or empty string.
    /// Lookups are case-insensitive on the user-typed exercise name so
    /// "Bench Press" and "bench press" surface the same note.
    func pinnedNote(for exerciseName: String) -> String {
        let all = loadAll()
        return all[exerciseName.lowercased()] ?? ""
    }

    func setPinnedNote(_ note: String, for exerciseName: String) {
        var all = loadAll()
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            all.removeValue(forKey: exerciseName.lowercased())
        } else {
            all[exerciseName.lowercased()] = trimmed
        }
        save(all)
    }

    func clearPinnedNote(for exerciseName: String) {
        var all = loadAll()
        all.removeValue(forKey: exerciseName.lowercased())
        save(all)
    }

    private func loadAll() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func save(_ dict: [String: String]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
