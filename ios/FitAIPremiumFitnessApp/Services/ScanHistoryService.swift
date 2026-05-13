import Foundation

class ScanHistoryService {
    static let shared = ScanHistoryService()
    private let key = "scanHistory"
    private let queue = DispatchQueue(label: "com.fitai.scanHistoryService")

    func save(_ entry: ScanHistoryEntry) {
        queue.sync {
            var history = _loadAll()
            history.insert(entry, at: 0)
            if history.count > 50 {
                history = Array(history.prefix(50))
            }
            if let data = try? JSONEncoder().encode(history) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func loadAll() -> [ScanHistoryEntry] {
        queue.sync { _loadAll() }
    }

    func clear() {
        queue.sync {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Internal load without queue synchronization — must be called from within `queue.sync`.
    private func _loadAll() -> [ScanHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([ScanHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }
}

nonisolated struct ScanHistoryEntry: Codable, Sendable, Identifiable {
    let id: String
    let date: Date
    let overallScore: Double
    let potentialRating: Double
    let muscleMassRating: String
    let strongPoints: [String]
    let weakPoints: [String]
    let summary: String
    let recommendations: [String]
    let muscleScores: CodableMuscleScores
    /// Canonical muscle keys the AI could actually see in the photo
    /// (e.g. ["chest", "shoulders", "arms"]). The original ScanResult
    /// returns this as a separate field; without it, the latest-result
    /// re-render in ScanView falls back to strongPoints+weakPoints,
    /// which produces "Not graded this scan: <every muscle>" because
    /// the strong/weak lists are free-form text, not the canonical keys
    /// the disclosure logic expects. Optional in the Codable shape so
    /// old persisted entries decode cleanly with an empty list.
    let visibleMuscleGroups: [String]

    enum CodingKeys: String, CodingKey {
        case id, date, overallScore, potentialRating, muscleMassRating
        case strongPoints, weakPoints, summary, recommendations
        case muscleScores, visibleMuscleGroups
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.date = try c.decode(Date.self, forKey: .date)
        self.overallScore = try c.decode(Double.self, forKey: .overallScore)
        self.potentialRating = try c.decode(Double.self, forKey: .potentialRating)
        self.muscleMassRating = try c.decode(String.self, forKey: .muscleMassRating)
        self.strongPoints = try c.decode([String].self, forKey: .strongPoints)
        self.weakPoints = try c.decode([String].self, forKey: .weakPoints)
        self.summary = try c.decode(String.self, forKey: .summary)
        self.recommendations = try c.decode([String].self, forKey: .recommendations)
        self.muscleScores = try c.decode(CodableMuscleScores.self, forKey: .muscleScores)
        self.visibleMuscleGroups = try c.decodeIfPresent([String].self, forKey: .visibleMuscleGroups) ?? []
    }

    init(from result: ScanResult) {
        self.id = result.id
        self.date = result.date
        self.overallScore = result.overallScore
        self.potentialRating = result.potentialRating
        self.muscleMassRating = result.muscleMassRating
        self.strongPoints = result.strongPoints
        self.weakPoints = result.weakPoints
        self.summary = result.summary
        self.recommendations = result.recommendations
        self.muscleScores = CodableMuscleScores(from: result.muscleScores)
        self.visibleMuscleGroups = result.visibleMuscleGroups
    }

    init(id: String, date: Date, overallScore: Double, potentialRating: Double, muscleMassRating: String, strongPoints: [String], weakPoints: [String], summary: String, recommendations: [String], muscleScores: CodableMuscleScores, visibleMuscleGroups: [String] = []) {
        self.id = id
        self.date = date
        self.overallScore = overallScore
        self.potentialRating = potentialRating
        self.muscleMassRating = muscleMassRating
        self.strongPoints = strongPoints
        self.weakPoints = weakPoints
        self.summary = summary
        self.recommendations = recommendations
        self.muscleScores = muscleScores
        self.visibleMuscleGroups = visibleMuscleGroups
    }
}

nonisolated struct CodableMuscleScores: Codable, Sendable, Hashable {
    let chest: Double
    let shoulders: Double
    let back: Double
    let arms: Double
    let legs: Double
    let core: Double
    /// Optional in storage so older saved entries (without glutes) still decode.
    let glutes: Double?

    init(from scores: MuscleScores) {
        self.chest = scores.chest
        self.shoulders = scores.shoulders
        self.back = scores.back
        self.arms = scores.arms
        self.legs = scores.legs
        self.core = scores.core
        self.glutes = scores.glutes
    }

    func toMuscleScores() -> MuscleScores {
        MuscleScores(chest: chest, shoulders: shoulders, back: back, arms: arms, legs: legs, core: core, glutes: glutes ?? 0)
    }
}
