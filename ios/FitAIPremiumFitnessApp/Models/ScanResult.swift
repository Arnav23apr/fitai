import Foundation
import UIKit

struct MuscleScores {
    let chest: Double
    let shoulders: Double
    let back: Double
    let arms: Double
    let legs: Double
    let core: Double
    let glutes: Double
}

struct ScanResult: Identifiable {
    let id: String = UUID().uuidString
    let date: Date
    let overallScore: Double
    let strongPoints: [String]
    let weakPoints: [String]
    let summary: String
    let recommendations: [String]
    let potentialRating: Double
    let muscleMassRating: String
    let muscleScores: MuscleScores
    let visibleMuscleGroups: [String]
    var frontPhoto: UIImage? = nil
}

struct TransformationResult: Identifiable {
    let id: String = UUID().uuidString
    /// Clean AI photo, no baked branding. Used for in-app display and the
    /// diptych share card (so both before/after halves match visually).
    let image: UIImage
    /// Same photo with the disclosure band baked into the bottom. Used as
    /// the fallback when the user save-to-photos or screenshot-grabs the
    /// raw image instead of going through the share-card flow.
    let brandedImage: UIImage
    let description: String
}
