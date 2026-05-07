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
        /// When the current rest period ends. Set to a future Date when the
        /// user starts resting; nil otherwise. The widget renders the
        /// countdown via `Text(timerInterval:countsDown:)` so iOS keeps
        /// updating the lock-screen / Dynamic Island timer without the app
        /// having to push a new state every second.
        var restEndsAt: Date?

        /// True if rest is still ticking down. Derived from `restEndsAt`
        /// so the widget can hide the rest UI as soon as the timer expires
        /// without an explicit update.
        var isResting: Bool {
            guard let end = restEndsAt else { return false }
            return end > Date()
        }
    }

    var workoutDayLabel: String
}
