import SwiftUI

struct WorkoutHistoryDetailSheet: View {
    let log: WorkoutLog

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var shareData: IdentifiableShareData? = nil

    private let logService = ExerciseLogService.shared

    /// Exercise logs recorded on the same calendar day as the workout.
    private var dailyExerciseLogs: [ExerciseLog] {
        let cal = Calendar.current
        let day = cal.startOfDay(for: log.date)
        let nextDay = cal.date(byAdding: .day, value: 1, to: day) ?? day
        return logService.loadAll().filter { $0.date >= day && $0.date < nextDay }
    }

    private var totalVolume: Double {
        dailyExerciseLogs.reduce(0) { $0 + $1.computedVolume }
    }

    private var totalSets: Int {
        dailyExerciseLogs.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    private var weightUnit: String {
        appState.profile.usesMetric ? "kg" : "lbs"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    summaryCard
                    if dailyExerciseLogs.isEmpty {
                        completedNamesCard
                    } else {
                        exercisesCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle(log.dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        shareData = IdentifiableShareData(data: buildShareData())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .fullScreenCover(item: $shareData) { item in
                WorkoutShareOverlay(data: item.data, onDismiss: { shareData = nil })
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let isFullyCompleted = log.exercisesCompleted == log.totalExercises
        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(isFullyCompleted ? .green : .orange)
                        Text("\(log.exercisesCompleted) of \(log.totalExercises) exercises")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 0) {
                summaryStat(value: "\(log.durationMinutes)", unit: "min", label: "Duration")
                divider
                summaryStat(value: "\(totalSets)", unit: nil, label: "Sets")
                divider
                summaryStat(value: volumeText, unit: weightUnit, label: "Volume")
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var volumeText: String {
        let v = Int(totalVolume)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func summaryStat(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    // MARK: - Exercises

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(dailyExerciseLogs) { ex in
                    exerciseRow(ex)
                }
            }
        }
    }

    private func exerciseRow(_ ex: ExerciseLog) -> some View {
        let completedSets = ex.sets.filter(\.isCompleted)
        return VStack(alignment: .leading, spacing: 10) {
            exerciseRowHeader(ex, completedSets: completedSets)
            if !completedSets.isEmpty {
                exerciseSetsList(completedSets)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func exerciseRowHeader(_ ex: ExerciseLog, completedSets: [SetLog]) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if !ex.muscleGroup.isEmpty {
                    Text(ex.muscleGroup)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text("\(completedSets.count) sets")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(.capsule)
        }
    }

    private func exerciseSetsList(_ sets: [SetLog]) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(sets.enumerated()), id: \.offset) { idx, set in
                exerciseSetRow(index: idx, set: set)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func exerciseSetRow(index: Int, set: SetLog) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .leading)
            Text(setText(set))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            if set.isFailure { tagPill("F", color: .red) }
            if set.isDropSet { tagPill("DS", color: .orange) }
        }
    }

    private func setText(_ set: SetLog) -> String {
        if set.isBodyweight || set.weight == 0 {
            return "\(set.reps) reps · BW"
        }
        let w = Int(set.weight)
        return "\(w)\(weightUnit) × \(set.reps)"
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(.capsule)
    }

    // MARK: - Fallback (no per-set logs found)

    private var completedNamesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(log.completedExerciseNames, id: \.self) { name in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }

            if log.completedExerciseNames.isEmpty {
                Text("Per-set details aren't available for this workout.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Share data

    private func buildShareData() -> WorkoutShareCardData {
        // Top set across the day's logged sets
        var topName = ""
        var topW: Double = 0
        var topR: Int = 0
        for ex in dailyExerciseLogs {
            for s in ex.sets where s.isCompleted {
                if s.weight > topW {
                    topW = s.weight
                    topR = s.reps
                    topName = ex.exerciseName
                }
            }
        }

        let estCal = Int(Double(log.durationMinutes) * 5.5 + totalVolume * 0.015)

        return WorkoutShareCardData(
            workoutName: log.dayName,
            focusAreas: [],
            totalVolume: totalVolume,
            duration: log.durationMinutes,
            exercisesCompleted: log.exercisesCompleted,
            totalExercises: log.totalExercises,
            totalSets: totalSets,
            prCount: 0,
            prExerciseNames: [],
            pointsEarned: 0,
            prBestWeight: 0,
            prBestReps: 0,
            weightUnit: weightUnit,
            topSetExercise: topName,
            topSetWeight: topW,
            topSetReps: topR,
            estimatedCalories: estCal,
            exercises: [],
            workoutDate: log.date
        )
    }
}
