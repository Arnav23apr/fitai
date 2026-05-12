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
///
/// Cloud sync: AppState wires `onChange` at launch so every local write
/// also fires an upsert/delete on the `exercise_notes` table (migration
/// 023). Restoring on a new device pulls those rows back via
/// `SupabaseSyncService.fetchExerciseNotes` and hands them to
/// `hydrate(_:)`.
class ExerciseNoteService {
    static let shared = ExerciseNoteService()
    private let key = "exerciseNotes_pinned_v1"

    /// One of `.set(name, body)` / `.clear(name)`. Fired after every
    /// successful local write so AppState can mirror the change to the
    /// cloud table. AppState sets this once at launch via the
    /// `onChange` callback below.
    enum Change {
        case set(name: String, body: String)
        case clear(name: String)
    }
    var onChange: ((Change) -> Void)? = nil

    /// Returns the pinned note for an exercise name, or empty string.
    /// Lookups are case-insensitive on the user-typed exercise name so
    /// "Bench Press" and "bench press" surface the same note.
    func pinnedNote(for exerciseName: String) -> String {
        let all = loadAll()
        return all[exerciseName.lowercased()] ?? ""
    }

    func setPinnedNote(_ note: String, for exerciseName: String) {
        var all = loadAll()
        let lowered = exerciseName.lowercased()
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            all.removeValue(forKey: lowered)
            save(all)
            onChange?(.clear(name: lowered))
        } else {
            all[lowered] = trimmed
            save(all)
            onChange?(.set(name: lowered, body: trimmed))
        }
    }

    func clearPinnedNote(for exerciseName: String) {
        var all = loadAll()
        let lowered = exerciseName.lowercased()
        all.removeValue(forKey: lowered)
        save(all)
        onChange?(.clear(name: lowered))
    }

    /// Replace the local cache with a fresh dict from the cloud. Called
    /// once during sign-in / restore. Doesn't fire `onChange` callbacks
    /// — this is the inbound side of sync, not an outbound mutation.
    func hydrate(_ dict: [String: String]) {
        // Normalize keys to lowercased (cloud row was already lowercased
        // on write, but defensive).
        var normalized: [String: String] = [:]
        for (k, v) in dict {
            normalized[k.lowercased()] = v
        }
        save(normalized)
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
