import SwiftUI

/// Strava-style 12-week commit-graph for workout consistency. Reads dates
/// from `[WorkoutLog]` and renders a 7-row × N-col grid where each cell's
/// opacity scales with that day's workout intensity (exercises completed).
///
/// Tapping a filled cell opens `WorkoutHistoryDetailSheet` for that day's
/// most recent log; empty past cells silently bounce-haptic; future cells
/// are no-op. Today's cell shows a pulsing outline so "now" is findable.
struct WorkoutCalendarHeatmap: View {
    let logs: [WorkoutLog]
    /// Number of past weeks to display. 12 = ~3 months, 26 = ~6 months.
    let weekCount: Int

    @State private var selectedLog: WorkoutLog? = nil
    @State private var pulse: Bool = false
    @State private var emptyTapTrigger: Int = 0

    init(logs: [WorkoutLog], weekCount: Int = 12) {
        self.logs = logs
        self.weekCount = weekCount
    }

    private struct DayCell: Identifiable {
        let id: Int  // unique index in the rendered grid
        let date: Date
        let intensity: Double  // 0–1, derived from exercises completed
        let inFuture: Bool
        let isToday: Bool
        /// All logs on this day, most recent first. nil-equivalent if empty.
        let logs: [WorkoutLog]
    }

    /// Calendar columns starting Sunday on the leftmost week.
    private var grid: [[DayCell]] {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        // Walk back to the start of the earliest week we'll render.
        guard let earliestStart = cal.date(
            byAdding: .day,
            value: -(weekCount * 7 - 1),
            to: today
        ) else { return [] }

        // Snap to that day's Sunday so columns align.
        let weekday = cal.component(.weekday, from: earliestStart)  // 1=Sun
        let columnStart = cal.date(byAdding: .day, value: -(weekday - 1), to: earliestStart) ?? earliestStart

        // Group logs by start-of-day for O(1) lookup. Each day's bucket is
        // sorted most-recent-first so a tap on a multi-workout day opens
        // the latest session.
        let logsByDay: [Date: [WorkoutLog]] = Dictionary(
            grouping: logs,
            by: { cal.startOfDay(for: $0.date) }
        ).mapValues { $0.sorted { $0.date > $1.date } }

        var cols: [[DayCell]] = []
        for col in 0..<(weekCount + 1) {
            var rows: [DayCell] = []
            for row in 0..<7 {
                let dayOffset = col * 7 + row
                guard let date = cal.date(byAdding: .day, value: dayOffset, to: columnStart) else { continue }
                let dayKey = cal.startOfDay(for: date)
                let inFuture = dayKey > today
                let dayLogs = inFuture ? [] : (logsByDay[dayKey] ?? [])
                // Cap intensity at "8+ exercises = full color" so the gradient
                // doesn't wash out for power users.
                let totalEx = dayLogs.reduce(0) { $0 + $1.exercisesCompleted }
                let intensity = min(Double(totalEx) / 8.0, 1.0)
                rows.append(DayCell(
                    id: dayOffset,
                    date: date,
                    intensity: intensity,
                    inFuture: inFuture,
                    isToday: dayKey == today,
                    logs: dayLogs
                ))
            }
            cols.append(rows)
        }
        return cols
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.subheadline.weight(.semibold))
                    Text("Last \(weekCount) weeks")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                legend
            }

            HStack(alignment: .top, spacing: 4) {
                ForEach(grid.indices, id: \.self) { colIdx in
                    VStack(spacing: 4) {
                        ForEach(grid[colIdx]) { day in
                            cellView(for: day)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .sheet(item: $selectedLog) { log in
            WorkoutHistoryDetailSheet(log: log)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: emptyTapTrigger)
    }

    private func cellView(for day: DayCell) -> some View {
        Button {
            handleTap(day)
        } label: {
            ZStack {
                Rectangle()
                    .fill(cellColor(for: day))
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                if day.isToday {
                    // Pulsing white ring on today's cell — makes "now"
                    // findable at a glance regardless of intensity.
                    Rectangle()
                        .strokeBorder(
                            Color.primary.opacity(pulse ? 0.85 : 0.40),
                            lineWidth: 1.4
                        )
                }
            }
            .frame(width: 12, height: 12)
            .clipShape(.rect(cornerRadius: 2))
            .opacity(day.inFuture ? 0.0 : 1.0)
            .contentShape(.rect)
        }
        .buttonStyle(CellPressStyle())
        .disabled(day.inFuture)
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func handleTap(_ day: DayCell) {
        guard !day.inFuture else { return }
        if let first = day.logs.first {
            selectedLog = first
        } else {
            // Empty past cell: tiny haptic so the tap registers as
            // intentional, no toast — those get noisy on a 84-cell grid.
            emptyTapTrigger += 1
        }
    }

    private func accessibilityLabel(for day: DayCell) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        let dateStr = f.string(from: day.date)
        if day.inFuture {
            return "\(dateStr), upcoming"
        }
        if day.logs.isEmpty {
            return "\(dateStr), no workout"
        }
        let total = day.logs.reduce(0) { $0 + $1.exercisesCompleted }
        let mins = day.logs.reduce(0) { $0 + $1.durationMinutes }
        return "\(dateStr), \(total) exercise\(total == 1 ? "" : "s"), \(mins) minutes. Tap to open."
    }

    private func cellColor(for day: DayCell) -> Color {
        if day.intensity == 0 {
            return Color.primary.opacity(0.06)
        }
        // Lerp from light to vibrant orange — matches FitAI's flame.fill /
        // streak iconography elsewhere in the app.
        let base = Color.orange
        // 0.20 minimum so a single-exercise day still reads, 0.95 max.
        return base.opacity(0.20 + day.intensity * 0.75)
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                Rectangle()
                    .fill(legendColor(intensity))
                    .frame(width: 9, height: 9)
                    .clipShape(.rect(cornerRadius: 2))
            }
            Text("More")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func legendColor(_ intensity: Double) -> Color {
        if intensity == 0 { return Color.primary.opacity(0.06) }
        return Color.orange.opacity(0.20 + intensity * 0.75)
    }
}

/// Subtle scale-down on press — gives tactile feedback at 12pt scale where
/// the default button highlight would be invisible.
private struct CellPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.78 : 1.0)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
    }
}
