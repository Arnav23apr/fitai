import SwiftUI

/// Hevy/Strong-style "Exercises" browser. Lists every exercise the
/// user has actually logged, sorted by most recently trained, with
/// inline search. Tapping a row opens the per-exercise progress chart
/// directly so the lifter can see weight / 1RM / volume trends without
/// having to enter an active session first.
///
/// Empty state suggests starting a workout, since with no logs there
/// are no exercises to browse. This is the missing top-level entry
/// point that competitors expose as a dedicated "Exercises" tab.
struct ExercisesBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var query: String = ""
    @State private var selectedExerciseName: String? = nil

    private let logService = ExerciseLogService.shared

    private var allExerciseSummaries: [Summary] {
        let logs = logService.loadAll()
        let grouped = Dictionary(grouping: logs, by: { $0.exerciseName })
        return grouped.compactMap { (name, logs) -> Summary? in
            guard !logs.isEmpty else { return nil }
            let sorted = logs.sorted { $0.date > $1.date }
            let last = sorted.first!
            let history = ExerciseHistory(exerciseName: name, logs: logs)
            return Summary(
                name: name,
                muscleGroup: last.muscleGroup,
                lastDate: last.date,
                sessionCount: logs.count,
                bestWeight: history.personalBestWeight,
                bestEstOneRM: history.personalBestEstimatedOneRM
            )
        }
        .sorted { $0.lastDate > $1.lastDate }
    }

    private var filtered: [Summary] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allExerciseSummaries }
        return allExerciseSummaries.filter { s in
            s.name.lowercased().contains(q) ||
            s.muscleGroup.lowercased().contains(q)
        }
    }

    private var unitLabel: String { appState.profile.usesMetric ? "kg" : "lbs" }

    var body: some View {
        NavigationStack {
            Group {
                if allExerciseSummaries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search exercises"
            )
            .sheet(item: Binding<NamedExercise?>(
                get: { selectedExerciseName.map { NamedExercise(name: $0) } },
                set: { selectedExerciseName = $0?.name }
            )) { wrapper in
                NavigationStack {
                    ExerciseProgressChartView(
                        exerciseName: wrapper.name,
                        usesMetric: appState.profile.usesMetric
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedExerciseName = nil }
                        }
                    }
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(filtered) { summary in
                Button {
                    selectedExerciseName = summary.name
                } label: {
                    rowContent(for: summary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func rowContent(for summary: Summary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.20), Color.indigo.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !summary.muscleGroup.isEmpty {
                        Text(summary.muscleGroup)
                    }
                    if !summary.muscleGroup.isEmpty { Text("·") }
                    Text("\(summary.sessionCount) session\(summary.sessionCount == 1 ? "" : "s")")
                    if summary.bestWeight > 0 {
                        Text("·")
                        Text("Best \(Int(summary.bestWeight)) \(unitLabel)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if summary.bestEstOneRM > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(summary.bestEstOneRM))")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.orange)
                    Text("est. 1RM")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No exercises logged yet")
                .font(.headline)
            Text("Once you finish a workout, every exercise you log will show up here with its progression chart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Summary: Identifiable {
    var id: String { name }
    let name: String
    let muscleGroup: String
    let lastDate: Date
    let sessionCount: Int
    let bestWeight: Double
    let bestEstOneRM: Double
}

private struct NamedExercise: Identifiable {
    var id: String { name }
    let name: String
}
