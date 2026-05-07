import ActivityKit
import WidgetKit
import SwiftUI

struct FitAIWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setNumber: Int
        var totalSets: Int
        var elapsedSeconds: Int
    }
    var workoutName: String
}

struct FitAIWorkoutActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FitAIWorkoutActivityAttributes.self) { context in
            // Lock screen / banner UI
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.workoutName)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(context.state.exerciseName) · Set \(context.state.setNumber)/\(context.state.totalSets)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Text(Duration.seconds(context.state.elapsedSeconds), format: .time(pattern: .minuteSecond))
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .activityBackgroundTint(Color(red: 0.08, green: 0.08, blue: 0.10))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Duration.seconds(context.state.elapsedSeconds), format: .time(pattern: .minuteSecond))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.exerciseName) · Set \(context.state.setNumber)/\(context.state.totalSets)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(Duration.seconds(context.state.elapsedSeconds), format: .time(pattern: .minuteSecond))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 40)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
