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
    /// Optional back-pose photo captured during the same scan session. Tap
    /// the photo on the rated card to flip front ↔ back. nil when the user
    /// skipped the back capture (e.g., one-photo mode), in which case the
    /// flip affordance is hidden.
    var backPhoto: UIImage? = nil
    /// True when this result is a placeholder for a free-tier user who saw the
    /// scan animation but did NOT have their photo sent to the AI. The scan
    /// results sheet renders blurred values + an unlock CTA. Premium users
    /// always get isLocked = false.
    var isLocked: Bool = false
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
