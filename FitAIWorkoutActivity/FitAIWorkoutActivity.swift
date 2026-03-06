import WidgetKit
import SwiftUI
import ActivityKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.workoutIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.green)
                        Text(context.state.workoutName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startTime, style: .timer)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        expandedProgressBar(context: context)

                        HStack {
                            if !context.state.currentExerciseName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(context.state.currentExerciseName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if context.state.isResting && context.state.restSecondsRemaining > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                    Text("Rest \(formatSeconds(context.state.restSecondsRemaining))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: context.state.workoutIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.startTime, style: .timer)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.green)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: context.state.workoutIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: context.state.workoutIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                    Text(context.state.workoutName)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                }
                Spacer()
                Text(context.state.startTime, style: .timer)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.green)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                let progress = context.state.totalExercises > 0
                    ? Double(context.state.exercisesCompleted) / Double(context.state.totalExercises)
                    : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(.green)
                        .frame(width: max(geo.size.width * progress, 0), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                if !context.state.currentExerciseName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(context.state.currentExerciseName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises) exercises")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if context.state.isResting && context.state.restSecondsRemaining > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Rest: \(formatSeconds(context.state.restSecondsRemaining))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.12))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
    }

    private func expandedProgressBar(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                let progress = context.state.totalExercises > 0
                    ? Double(context.state.exercisesCompleted) / Double(context.state.totalExercises)
                    : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(.green)
                        .frame(width: max(geo.size.width * progress, 0), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entries = [SimpleEntry(date: .now)]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

nonisolated struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct FitAIWorkoutActivity: Widget {
    let kind: String = "FitAIWorkoutActivity"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Text(entry.date, style: .time)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FitAI Workout")
        .supportedFamilies([.systemSmall])
    }
}
