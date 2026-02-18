import Foundation

nonisolated struct SetLog: Codable, Identifiable, Sendable {
    let id: String
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var isFailure: Bool
    var isDropSet: Bool
    var timestamp: Date

    init(id: String = UUID().uuidString, weight: Double = 0, reps: Int = 0, isCompleted: Bool = false, isFailure: Bool = false, isDropSet: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.isFailure = isFailure
        self.isDropSet = isDropSet
        self.timestamp = timestamp
    }
}

nonisolated struct ExerciseLog: Codable, Identifiable, Sendable {
    let id: String
    let exerciseName: String
    let muscleGroup: String
    let date: Date
    var sets: [SetLog]
    var totalVolume: Double

    init(id: String = UUID().uuidString, exerciseName: String, muscleGroup: String, date: Date = Date(), sets: [SetLog] = [], totalVolume: Double = 0) {
        self.id = id
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.date = date
        self.sets = sets
        self.totalVolume = totalVolume
    }

    var computedVolume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var bestSetWeight: Double {
        sets.filter(\.isCompleted).map(\.weight).max() ?? 0
    }

    var bestSetReps: Int {
        sets.filter(\.isCompleted).map(\.reps).max() ?? 0
    }
}

nonisolated struct ExerciseHistory: Codable, Sendable {
    let exerciseName: String
    var logs: [ExerciseLog]

    var personalBestWeight: Double {
        logs.flatMap(\.sets).filter(\.isCompleted).map(\.weight).max() ?? 0
    }

    var personalBestReps: Int {
        logs.flatMap(\.sets).filter(\.isCompleted).map(\.reps).max() ?? 0
    }

    var personalBestVolume: Double {
        logs.map(\.computedVolume).max() ?? 0
    }

    var lastSession: ExerciseLog? {
        logs.sorted { $0.date > $1.date }.first
    }

    var volumeTrend: VolumeTrend {
        guard logs.count >= 2 else { return .neutral }
        let sorted = logs.sorted { $0.date > $1.date }
        let recent = sorted[0].computedVolume
        let previous = sorted[1].computedVolume
        if recent > previous * 1.05 { return .up }
        if recent < previous * 0.95 { return .down }
        return .neutral
    }

    var isPRReady: Bool {
        guard let last = lastSession else { return false }
        let bestWeight = personalBestWeight
        let lastBest = last.bestSetWeight
        return lastBest >= bestWeight * 0.9 && lastBest < bestWeight
    }
}

nonisolated enum VolumeTrend: String, Codable, Sendable {
    case up
    case down
    case neutral

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "arrow.right"
        }
    }

    var color: String {
        switch self {
        case .up: return "green"
        case .down: return "red"
        case .neutral: return "secondary"
        }
    }
}
