import SwiftUI
import MuscleMap

struct MuscleDetailSheet: View {
    let muscle: Muscle
    let exercises: [Exercise]
    let exerciseLogs: [ExerciseLog]

    @Environment(\.dismiss) private var dismiss

    private let mapper = MuscleMapperService.shared

    private var matchingExercises: [Exercise] {
        mapper.exercisesTargeting(muscle: muscle, from: exercises)
    }

    private var weeklyLogs: [ExerciseLog] {
        let calendar = Calendar.current
        let now = Date()
        return exerciseLogs.filter { log in
            guard calendar.isDate(log.date, equalTo: now, toGranularity: .weekOfYear) else { return false }
            let m = mapper.mapping(for: log.exerciseName, muscleGroup: log.muscleGroup)
            return m.primary.contains(muscle) || m.secondary.contains(muscle)
        }
    }

    private var totalSets: Int {
        weeklyLogs.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    private var totalVolume: Double {
        weeklyLogs.reduce(0) { $0 + $1.computedVolume }
    }

    private var isPrimary: Bool {
        matchingExercises.contains { exercise in
            let m = mapper.mapping(for: exercise.name, muscleGroup: exercise.muscleGroup)
            return m.primary.contains(muscle)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    muscleHeader

                    if totalSets > 0 {
                        weeklyStats
                    }

                    if !matchingExercises.isEmpty {
                        exerciseList
                    }

                    if !weeklyLogs.isEmpty {
                        recentActivity
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(mapper.muscleToString(muscle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var muscleHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isPrimary ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 22))
                    .foregroundStyle(isPrimary ? .red : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mapper.muscleToString(muscle))
                    .font(.title3.weight(.bold))
                HStack(spacing: 8) {
                    Text(isPrimary ? "Primary Target" : "Secondary Target")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isPrimary ? .red : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((isPrimary ? Color.red : Color.orange).opacity(0.12))
                        .clipShape(.capsule)
                    if totalSets > 0 {
                        Text("\(totalSets) sets this week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var weeklyStats: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                Text("This Week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 0) {
                statItem(value: "\(totalSets)", label: "Sets", icon: "square.stack.fill", color: .blue)
                statDivider
                statItem(value: "\(weeklyLogs.count)", label: "Sessions", icon: "calendar", color: .green)
                statDivider
                statItem(value: formatVolume(totalVolume), label: "Volume", icon: "scalemass.fill", color: .purple)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("Exercises Targeting This Muscle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(matchingExercises) { exercise in
                let m = mapper.mapping(for: exercise.name, muscleGroup: exercise.muscleGroup)
                let role = m.primary.contains(muscle) ? "Primary" : "Secondary"
                HStack(spacing: 12) {
                    Circle()
                        .fill(role == "Primary" ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(role == "Primary" ? .red : .orange)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.medium))
                        Text("\(exercise.sets) sets · \(exercise.reps) · \(role)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("Recent Activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(weeklyLogs.sorted(by: { $0.date > $1.date }).prefix(5)) { log in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.exerciseName)
                            .font(.subheadline.weight(.medium))
                        Text(log.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(log.sets.filter(\.isCompleted).count) sets")
                            .font(.caption.weight(.semibold))
                        if log.computedVolume > 0 {
                            Text("\(Int(log.computedVolume))kg")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}
