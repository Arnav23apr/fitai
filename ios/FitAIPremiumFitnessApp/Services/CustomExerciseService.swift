import Foundation

/// User-created exercises that aren't in the bundled database. Persisted to
/// UserDefaults locally and mirrored to Supabase `custom_exercises` so they
/// survive logout/reinstall — same pattern as `RoutineService` and
/// `BodyMeasurementService`.
@Observable
@MainActor
final class CustomExerciseService {
    static let shared = CustomExerciseService()

    private let storageKey = "customExercises.v1"

    private(set) var exercises: [CustomExercise]

    /// Set by AppState during sign-in. nil while signed-out — exercises
    /// are then local-only until auth completes.
    var currentUserId: String? = nil

    private init() {
        if let data = UserDefaults.standard.data(forKey: "customExercises.v1"),
           let decoded = try? JSONDecoder().decode([CustomExercise].self, from: data) {
            self.exercises = decoded
        } else {
            self.exercises = []
        }
    }

    func add(_ exercise: CustomExercise) {
        exercises.append(exercise)
        persist()
        pushToCloud(exercise)
    }

    func update(_ exercise: CustomExercise) {
        guard let idx = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[idx] = exercise
        persist()
        pushToCloud(exercise)
    }

    func remove(id: String) {
        exercises.removeAll { $0.id == id }
        persist()
        if let userId = currentUserId {
            Task.detached {
                await SupabaseSyncService.shared.deleteCustomExercise(userId: userId, id: id)
            }
        }
    }

    /// Replace local cache with remote — used by AppState.restoreFromCloud.
    func replaceAll(_ list: [CustomExercise]) {
        exercises = list
        persist()
    }

    /// Wipe local cache (called on logout). Cloud copy is preserved.
    func clearLocal() {
        exercises = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func pushToCloud(_ exercise: CustomExercise) {
        guard let userId = currentUserId else { return }
        Task.detached {
            await SupabaseSyncService.shared.upsertCustomExercise(userId: userId, exercise: exercise)
        }
    }

    /// Look up by name (case-insensitive). Returns nil if not a custom one.
    func info(forName name: String) -> CustomExercise? {
        let needle = name.lowercased()
        return exercises.first { $0.name.lowercased() == needle }
    }

    /// All custom exercise names. Used by the routine editor picker so
    /// they appear inline with the bundled catalog.
    var names: [String] {
        exercises.map(\.name).sorted()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

nonisolated struct CustomExercise: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var name: String
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var notes: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        primaryMuscle: String,
        secondaryMuscles: [String] = [],
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.notes = notes
        self.createdAt = createdAt
    }
}
