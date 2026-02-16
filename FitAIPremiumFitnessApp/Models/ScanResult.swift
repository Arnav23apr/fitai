import Foundation
import UIKit

struct MuscleScores {
    let chest: Double
    let shoulders: Double
    let back: Double
    let arms: Double
    let legs: Double
    let core: Double
}

struct ScanResult: Identifiable {
    let id: String = UUID().uuidString
    let date: Date
    let overallScore: Double
    let strongPoints: [String]
    let weakPoints: [String]
    let summary: String
    let recommendations: [String]
    let bodyFatEstimate: String
    let muscleMassRating: String
    let muscleScores: MuscleScores
    let visibleMuscleGroups: [String]
    var frontPhoto: UIImage? = nil
}

struct TransformationResult: Identifiable {
    let id: String = UUID().uuidString
    let image: UIImage
    let description: String
}
