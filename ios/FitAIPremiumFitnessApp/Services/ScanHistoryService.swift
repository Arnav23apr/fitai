import Foundation

class ScanHistoryService {
    static let shared = ScanHistoryService()
    private let key = "scanHistory"

    func save(_ entry: ScanHistoryEntry) {
        var history = loadAll()
        history.insert(entry, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadAll() -> [ScanHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([ScanHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
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
