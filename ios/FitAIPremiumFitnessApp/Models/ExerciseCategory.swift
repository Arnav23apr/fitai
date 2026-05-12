import Foundation

/// Movement type used by `RestRecommender` to pick a sensible rest default.
/// Heavy compounds (squat, dead, bench, OHP, row) need the longest rest;
/// isolations recover fast.
nonisolated enum ExerciseCategory: String, Sendable, Codable {
    case heavyCompound
    case compound
    case isolation
    case unknown
}
