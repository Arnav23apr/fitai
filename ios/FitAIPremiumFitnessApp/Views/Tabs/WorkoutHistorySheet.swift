import SwiftUI

struct WorkoutHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedLog: WorkoutLog? = nil

    private var lang: String { appState.profile.selectedLanguage }

    /// Full history (used for the stats row totals so free users
    /// still see the truthful "X total workouts" number) AND to
    /// compute how many sessions sit behind the paywall.
    private var allLogs: [WorkoutLog] {
        appState.profile.workoutLogs.sorted { $0.date > $1.date }
    }

    /// Logs the user is allowed to see in the list. Free tier is
    /// capped to `historyCutoffDate` (30 days); Pro returns
    /// everything.
    private var logs: [WorkoutLog] {
        let cutoff = appState.profile.historyCutoffDate
        return allLogs.filter { $0.date >= cutoff }
    }

    private var lockedHistoryCount: Int {
        allLogs.count - logs.count
    }

    private var groupedLogs: [(String, [WorkoutLog])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: logs) { formatter.string(from: $0.date) }
        return grouped.sorted { lhs, rhs in
            guard let l = lhs.value.first?.date, let r = rhs.value.first?.date else { return false }
            return l > r
        }
    }

    private var totalMinutes: Int {
        // Stats row shows truthful all-time totals so free users
        // know what they've actually done — the paywall hides the
        // *list* of older sessions, not the summary numbers.
        allLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalExercises: Int {
        allLogs.reduce(0) { $0 + $1.exercisesCompleted }
    }

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            statsRow
                            logsList
                            if lockedHistoryCount > 0 {
                                LockedHistoryCard(hiddenCount: lockedHistoryCount)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("workoutHistoryTitle", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .sheet(item: $selectedLog) { log in
                WorkoutHistoryDetailSheet(log: log)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(logs.count)",
                label: "Workouts",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )
            statDivider
            statItem(
                value: formatDuration(totalMinutes),
                label: "Total Time",
                icon: "clock.fill",
                color: .green
            )
            statDivider
            statItem(
                value: "\(totalExercises)",
                label: "Exercises",
                icon: "list.bullet",
                color: .purple
            )
            statDivider
            statItem(
                value: "\(appState.profile.currentStreak)",
                label: "Streak",
                icon: "flame.fill",
                color: .orange
            )
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 36)
    }

    // MARK: - Logs List

    private var logsList: some View {
        VStack(spacing: 20) {
            ForEach(groupedLogs, id: \.0) { month, monthLogs in
                VStack(alignment: .leading, spacing: 10) {
                    Text(month)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    VStack(spacing: 8) {
                        ForEach(monthLogs) { log in
                            Button {
                                selectedLog = log
                            } label: {
                                logRow(log)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func logRow(_ log: WorkoutLog) -> some View {
        let completionRatio = log.totalExercises > 0
            ? Double(log.exercisesCompleted) / Double(log.totalExercises)
            : 0
        let isFullyCompleted = log.exercisesCompleted == log.totalExercises

        return HStack(spacing: 14) {
            // Completion indicator
            ZStack {
                Circle()
                    .fill(isFullyCompleted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: isFullyCompleted ? "checkmark" : "figure.strengthtraining.traditional")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFullyCompleted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.dayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(log.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("\u{00B7}")
                        .foregroundStyle(.quaternary)
                    Text("\(log.durationMinutes)min")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(log.exercisesCompleted)/\(log.totalExercises)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(isFullyCompleted ? .green : .orange)

                if completionRatio < 1.0 && completionRatio > 0 {
                    Text("\(Int(completionRatio * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue.opacity(0.4))
            }

            Text("No Workouts Yet")
                .font(.title3.weight(.semibold))

            Text("Complete your first workout and it will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
