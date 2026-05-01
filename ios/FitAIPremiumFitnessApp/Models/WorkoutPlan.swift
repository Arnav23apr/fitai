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
    let suggestedWeights: [Double]
    let suggestedReps: [Int]

    var demoInfo: ExerciseDemoInfo {
        ExerciseDatabase.shared.info(for: name)
    }

    init(id: String = UUID().uuidString, name: String, sets: Int, reps: String, muscleGroup: String, suggestedWeights: [Double] = [], suggestedReps: [Int] = []) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.muscleGroup = muscleGroup
        self.suggestedWeights = suggestedWeights
        self.suggestedReps = suggestedReps
    }
}

nonisolated struct ExerciseDemoInfo: Sendable {
    let name: String
    let instructions: [String]
    let tips: [String]
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let videoURL: String
    let thumbnailURL: String
    let frames: [String]

    var hasMedia: Bool { !videoURL.isEmpty || !thumbnailURL.isEmpty || !frames.isEmpty }

    init(name: String, instructions: [String], tips: [String], primaryMuscles: [String], secondaryMuscles: [String], videoURL: String, thumbnailURL: String, frames: [String] = []) {
        self.name = name
        self.instructions = instructions
        self.tips = tips
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.frames = frames
    }

    static let empty = ExerciseDemoInfo(name: "", instructions: [], tips: [], primaryMuscles: [], secondaryMuscles: [], videoURL: "", thumbnailURL: "")
}

nonisolated struct WorkoutLog: Codable, Identifiable, Sendable {
    let id: String
    let date: Date
    let dayName: String
    let exercisesCompleted: Int
    let totalExercises: Int
    let durationMinutes: Int
    let completedExerciseNames: [String]

    init(id: String = UUID().uuidString, date: Date = Date(), dayName: String, exercisesCompleted: Int, totalExercises: Int, durationMinutes: Int, completedExerciseNames: [String] = []) {
        self.id = id
        self.date = date
        self.dayName = dayName
        self.exercisesCompleted = exercisesCompleted
        self.totalExercises = totalExercises
        self.durationMinutes = durationMinutes
        self.completedExerciseNames = completedExerciseNames
    }
}
