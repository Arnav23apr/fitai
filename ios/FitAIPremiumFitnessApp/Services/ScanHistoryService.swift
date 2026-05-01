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
    }

    init(id: String, date: Date, overallScore: Double, potentialRating: Double, muscleMassRating: String, strongPoints: [String], weakPoints: [String], summary: String, recommendations: [String], muscleScores: CodableMuscleScores) {
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
    }
}

nonisolated struct CodableMuscleScores: Codable, Sendable {
    let chest: Double
    let shoulders: Double
    let back: Double
    let arms: Double
    let legs: Double
    let core: Double

    init(from scores: MuscleScores) {
        self.chest = scores.chest
        self.shoulders = scores.shoulders
        self.back = scores.back
        self.arms = scores.arms
        self.legs = scores.legs
        self.core = scores.core
    }

    func toMuscleScores() -> MuscleScores {
        MuscleScores(chest: chest, shoulders: shoulders, back: back, arms: arms, legs: legs, core: core)
    }
}
