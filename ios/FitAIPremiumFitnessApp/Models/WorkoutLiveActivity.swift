import ActivityKit
import Foundation

nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var workoutName: String
        var workoutIcon: String
        var startTime: Date
        var exercisesCompleted: Int
        var totalExercises: Int
        var currentExerciseName: String
        var restSecondsRemaining: Int
        var isResting: Bool
    }

    var workoutDayLabel: String
}
