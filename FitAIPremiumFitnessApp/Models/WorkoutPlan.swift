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

    init(id: String = UUID().uuidString, name: String, sets: Int, reps: String, muscleGroup: String) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.muscleGroup = muscleGroup
    }
}
