import Foundation

/// Strong-style set tag. Tap the set number in ActiveSessionView to assign.
/// Warm-up sets are excluded from PR + volume calculations.
nonisolated enum SetType: String, Codable, Sendable, CaseIterable {
    case normal
    case warmup
    case dropSet
    case failure

    var badge: String {
        switch self {
        case .normal: return ""
        case .warmup: return "W"
        case .dropSet: return "D"
        case .failure: return "F"
        }
    }

    var label: String {
        switch self {
        case .normal: return "Normal Set"
        case .warmup: return "Warm-up Set"
        case .dropSet: return "Drop Set"
        case .failure: return "Failure Set"
        }
    }
}

nonisolated struct SetLog: Codable, Identifiable, Sendable {
    let id: String
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var isFailure: Bool
    var isDropSet: Bool
    var isBodyweight: Bool
    var timestamp: Date
    /// Strong-style set type. Source of truth going forward; the legacy
    /// `isFailure`/`isDropSet` fields are kept for backwards compatibility
    /// with previously-persisted logs and are mirrored on writes.
    var setType: SetType
    /// Rate of Perceived Exertion (6–10). nil = not recorded.
    var rpe: Double?
    /// Actual rest time taken before this set, in seconds. nil = not tracked.
    var restSeconds: Int?
    /// Per-set freeform note. nil = none.
    var note: String?

    init(
        id: String = UUID().uuidString,
        weight: Double = 0,
        reps: Int = 0,
        isCompleted: Bool = false,
        isFailure: Bool = false,
        isDropSet: Bool = false,
        isBodyweight: Bool = false,
        timestamp: Date = Date(),
        setType: SetType = .normal,
        rpe: Double? = nil,
        restSeconds: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.isFailure = isFailure
        self.isDropSet = isDropSet
        self.isBodyweight = isBodyweight
        self.timestamp = timestamp
        // Auto-derive setType when callers only set the legacy flags.
        if setType == .normal {
            if isFailure { self.setType = .failure }
            else if isDropSet { self.setType = .dropSet }
            else { self.setType = .normal }
        } else {
            self.setType = setType
        }
        self.rpe = rpe
        self.restSeconds = restSeconds
        self.note = note
    }

    // Custom decoder so legacy logs (no setType field) decode cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.weight = try c.decode(Double.self, forKey: .weight)
        self.reps = try c.decode(Int.self, forKey: .reps)
        self.isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        self.isFailure = try c.decodeIfPresent(Bool.self, forKey: .isFailure) ?? false
        self.isDropSet = try c.decodeIfPresent(Bool.self, forKey: .isDropSet) ?? false
        self.isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
        self.timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        if let raw = try c.decodeIfPresent(String.self, forKey: .setType),
           let t = SetType(rawValue: raw) {
            self.setType = t
        } else if isFailure {
            self.setType = .failure
        } else if isDropSet {
            self.setType = .dropSet
        } else {
            self.setType = .normal
        }
        self.rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        self.restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds)
        self.note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    /// True for sets that should count toward volume / PRs.
    var countsTowardVolume: Bool {
        isCompleted && setType != .warmup
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

    /// Working-set volume only — warm-ups excluded so they don't pollute PRs.
    var computedVolume: Double {
        sets.filter(\.countsTowardVolume).reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var bestSetWeight: Double {
        sets.filter(\.countsTowardVolume).map(\.weight).max() ?? 0
    }

    var bestSetReps: Int {
        sets.filter(\.countsTowardVolume).map(\.reps).max() ?? 0
    }
}

nonisolated struct ExerciseHistory: Codable, Sendable {
    let exerciseName: String
    var logs: [ExerciseLog]

    var personalBestWeight: Double {
        logs.flatMap(\.sets).filter(\.countsTowardVolume).map(\.weight).max() ?? 0
    }

    var personalBestReps: Int {
        logs.flatMap(\.sets).filter(\.countsTowardVolume).map(\.reps).max() ?? 0
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
