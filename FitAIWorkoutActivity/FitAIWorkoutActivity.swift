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
                    Capsule().fill(.white.opacity(0.15)).frame(height: 5)
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
                    Capsule().fill(.white.opacity(0.15)).frame(height: 4)
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

nonisolated struct FitAIWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let workoutName: String
    let exerciseCount: Int
    let streak: Int
    let latestScore: Double
}

nonisolated struct FitAIWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FitAIWidgetEntry {
        FitAIWidgetEntry(date: .now, workoutName: "Push Day", exerciseCount: 6, streak: 5, latestScore: 7.4)
    }

    func getSnapshot(in context: Context, completion: @escaping (FitAIWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FitAIWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> FitAIWidgetEntry {
        let defaults = UserDefaults.standard
        let workoutName = defaults.string(forKey: "widget_workoutName") ?? "Today's Workout"
        let exerciseCount = defaults.integer(forKey: "widget_exerciseCount")
        let streak = defaults.integer(forKey: "widget_streak")
        let latestScore = defaults.double(forKey: "widget_latestScore")
        return FitAIWidgetEntry(
            date: .now,
            workoutName: workoutName,
            exerciseCount: exerciseCount > 0 ? exerciseCount : 6,
            streak: streak,
            latestScore: latestScore
        )
    }
}

struct FitAISmallWidget: Widget {
    let kind: String = "FitAISmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitAIWidgetProvider()) { entry in
            FitAISmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Workout")
        .description("See your workout for today.")
        .supportedFamilies([.systemSmall])
    }
}

struct FitAIMediumWidget: Widget {
    let kind: String = "FitAIMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitAIWidgetProvider()) { entry in
            FitAIMediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FitAI Overview")
        .description("Workout and body scan score at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct FitAISmallWidgetView: View {
    let entry: FitAIWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                Text("TODAY")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.green)
                    .tracking(1)
            }

            Text(entry.workoutName)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(entry.exerciseCount) exercises")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if entry.streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("\(entry.streak) day streak")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }

            Text("Start →")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.primary.opacity(0.1))
                .clipShape(.capsule)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct FitAIMediumWidgetView: View {
    let entry: FitAIWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("TODAY'S WORKOUT")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.green)
                        .tracking(0.8)
                }

                Text(entry.workoutName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                HStack(spacing: 10) {
                    Label("\(entry.exerciseCount)", systemImage: "list.bullet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if entry.streak > 0 {
                        Label("\(entry.streak)🔥", systemImage: "flame.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }

                Text("Tap to start")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green)
                    .clipShape(.capsule)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(width: 1)

            VStack(spacing: 8) {
                Text("SCAN SCORE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                if entry.latestScore > 0 {
                    Text(String(format: "%.1f", entry.latestScore))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("/ 10")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(scoreLabel(entry.latestScore))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(scoreColor(entry.latestScore))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(scoreColor(entry.latestScore).opacity(0.12))
                        .clipShape(.capsule)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Scan to score")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(14)
            .frame(width: 110)
        }
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 8 { return "Excellent" }
        if score >= 7 { return "Great" }
        if score >= 5 { return "Good" }
        return "Keep Going"
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return .yellow }
        return .orange
    }
}

struct FitAIWorkoutActivity: Widget {
    let kind: String = "FitAIWorkoutActivity"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitAIWidgetProvider()) { entry in
            FitAISmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FitAI Workout")
        .description("Today's workout at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
