import Foundation
import SwiftUI

/// Persistence for user-created routines — local UserDefaults cache backed
/// by Supabase `user_routines`. Mutations write locally first then push to
/// cloud in a detached task. `replaceAll` is used by AppState during
/// post-sign-in restore.
@Observable
@MainActor
final class RoutineService {
    static let shared = RoutineService()

    private let key = "userRoutines"
    private let exampleSeededKey = "routineExamplesSeededV1"

    /// User-created routines.
    var routines: [Routine]

    /// Seeded read-only example templates (Strong 5x5 A/B, PPL, Upper/Lower).
    /// Mirrors Strong's "Example Templates" section. Loaded on first run only.
    var examples: [Routine]

    /// Free-tier user template cap (matches Strong's gating). Pro = unlimited.
    static let freeTemplateCap = 3

    /// Set by AppState during sign-in. nil while signed-out — routines are
    /// then local-only until auth completes.
    var currentUserId: String? = nil

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Routine].self, from: data) {
            self.routines = decoded
        } else {
            self.routines = []
        }
        self.examples = Self.builtInExamples()
    }

    /// Whether the user has hit the free-tier cap. Examples don't count.
    func atFreeCap(isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        return routines.count >= Self.freeTemplateCap
    }

    /// Save a routine. Returns false if the free cap would be exceeded.
    @discardableResult
    func save(_ routine: Routine, isPremium: Bool = true) -> Bool {
        let isExisting = routines.contains(where: { $0.id == routine.id })
        if !isExisting && atFreeCap(isPremium: isPremium) {
            return false
        }
        var updated = routine
        updated.updatedAt = Date()
        if let idx = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[idx] = updated
        } else {
            routines.append(updated)
        }
        persist()
        if let userId = currentUserId {
            let copy = updated
            Task.detached {
                await SupabaseSyncService.shared.upsertRoutine(userId: userId, routine: copy)
            }
        }
        return true
    }

    func delete(id: String) {
        routines.removeAll { $0.id == id }
        persist()
        if let userId = currentUserId {
            Task.detached {
                await SupabaseSyncService.shared.deleteRoutine(userId: userId, id: id)
            }
        }
    }

    func get(id: String) -> Routine? {
        routines.first { $0.id == id } ?? examples.first { $0.id == id }
    }

    /// Replace the entire local cache — used by `AppState.restoreFromCloud`
    /// to hydrate after a fresh sign-in. Skips cloud push since the source
    /// of truth is already cloud.
    func replaceAll(_ list: [Routine]) {
        routines = list
        persist()
    }

    /// Wipe local cache (called on logout). Cloud copy is preserved.
    func clearLocal() {
        routines = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Built-in example templates

    /// Mirrors Strong's bundled examples. These are static — never persisted
    /// to the user's routines list, never synced to cloud. They show up under
    /// the "Examples" section in the Workouts hub; tapping one starts the
    /// session immediately (Strong's behavior).
    private static func builtInExamples() -> [Routine] {
        [
            Routine(
                id: "example-5x5-a",
                name: "5×5 Strength — A",
                icon: "figure.strengthtraining.traditional",
                exercises: [
                    RoutineExercise(name: "Squat (Barbell)", sets: 5, reps: "5", muscleGroup: "Legs"),
                    RoutineExercise(name: "Bench Press (Barbell)", sets: 5, reps: "5", muscleGroup: "Chest"),
                    RoutineExercise(name: "Barbell Row", sets: 5, reps: "5", muscleGroup: "Back"),
                ],
                defaultRestSeconds: 180
            ),
            Routine(
                id: "example-5x5-b",
                name: "5×5 Strength — B",
                icon: "figure.strengthtraining.traditional",
                exercises: [
                    RoutineExercise(name: "Squat (Barbell)", sets: 5, reps: "5", muscleGroup: "Legs"),
                    RoutineExercise(name: "Overhead Press (Barbell)", sets: 5, reps: "5", muscleGroup: "Shoulders"),
                    RoutineExercise(name: "Deadlift (Barbell)", sets: 1, reps: "5", muscleGroup: "Back"),
                ],
                defaultRestSeconds: 180
            ),
            Routine(
                id: "example-ppl-push",
                name: "Push Day",
                icon: "dumbbell.fill",
                exercises: [
                    RoutineExercise(name: "Bench Press (Barbell)", sets: 4, reps: "6-8", muscleGroup: "Chest"),
                    RoutineExercise(name: "Overhead Press (Barbell)", sets: 4, reps: "8-10", muscleGroup: "Shoulders"),
                    RoutineExercise(name: "Incline Dumbbell Press", sets: 3, reps: "8-12", muscleGroup: "Chest"),
                    RoutineExercise(name: "Lateral Raise", sets: 3, reps: "12-15", muscleGroup: "Shoulders"),
                    RoutineExercise(name: "Tricep Pushdown", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
                ],
                defaultRestSeconds: 120
            ),
            Routine(
                id: "example-ppl-pull",
                name: "Pull Day",
                icon: "dumbbell.fill",
                exercises: [
                    RoutineExercise(name: "Deadlift (Barbell)", sets: 3, reps: "5", muscleGroup: "Back"),
                    RoutineExercise(name: "Pull-Up", sets: 3, reps: "AMRAP", muscleGroup: "Back"),
                    RoutineExercise(name: "Barbell Row", sets: 4, reps: "8-10", muscleGroup: "Back"),
                    RoutineExercise(name: "Face Pull", sets: 3, reps: "12-15", muscleGroup: "Shoulders"),
                    RoutineExercise(name: "Bicep Curl (Barbell)", sets: 3, reps: "10-12", muscleGroup: "Biceps"),
                ],
                defaultRestSeconds: 120
            ),
            Routine(
                id: "example-ppl-legs",
                name: "Leg Day",
                icon: "figure.strengthtraining.traditional",
                exercises: [
                    RoutineExercise(name: "Squat (Barbell)", sets: 4, reps: "6-8", muscleGroup: "Legs"),
                    RoutineExercise(name: "Romanian Deadlift", sets: 3, reps: "8-10", muscleGroup: "Hamstrings"),
                    RoutineExercise(name: "Leg Press", sets: 3, reps: "10-12", muscleGroup: "Legs"),
                    RoutineExercise(name: "Leg Curl (Machine)", sets: 3, reps: "10-12", muscleGroup: "Hamstrings"),
                    RoutineExercise(name: "Standing Calf Raise", sets: 4, reps: "10-15", muscleGroup: "Calves"),
                ],
                defaultRestSeconds: 120
            ),
            Routine(
                id: "example-upper",
                name: "Upper Body",
                icon: "dumbbell.fill",
                exercises: [
                    RoutineExercise(name: "Bench Press (Barbell)", sets: 4, reps: "6-8", muscleGroup: "Chest"),
                    RoutineExercise(name: "Barbell Row", sets: 4, reps: "8-10", muscleGroup: "Back"),
                    RoutineExercise(name: "Overhead Press (Barbell)", sets: 3, reps: "8-10", muscleGroup: "Shoulders"),
                    RoutineExercise(name: "Lat Pulldown", sets: 3, reps: "10-12", muscleGroup: "Back"),
                    RoutineExercise(name: "Bicep Curl (Dumbbell)", sets: 3, reps: "10-12", muscleGroup: "Biceps"),
                    RoutineExercise(name: "Tricep Pushdown", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
                ],
                defaultRestSeconds: 120
            ),
            Routine(
                id: "example-lower",
                name: "Lower Body",
                icon: "figure.strengthtraining.traditional",
                exercises: [
                    RoutineExercise(name: "Squat (Barbell)", sets: 4, reps: "6-8", muscleGroup: "Legs"),
                    RoutineExercise(name: "Romanian Deadlift", sets: 3, reps: "8-10", muscleGroup: "Hamstrings"),
                    RoutineExercise(name: "Leg Press", sets: 3, reps: "10-12", muscleGroup: "Legs"),
                    RoutineExercise(name: "Leg Curl (Machine)", sets: 3, reps: "10-12", muscleGroup: "Hamstrings"),
                    RoutineExercise(name: "Standing Calf Raise", sets: 4, reps: "10-15", muscleGroup: "Calves"),
                ],
                defaultRestSeconds: 120
            ),
        ]
    }
}
