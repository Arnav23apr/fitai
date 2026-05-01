import SwiftUI

struct WorkoutCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var displayedMonth: Date = Date()
    @State private var selectedLog: WorkoutLog? = nil

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    private var logs: [WorkoutLog] {
        appState.profile.workoutLogs
    }

    private var workoutsByDay: [Date: [WorkoutLog]] {
        Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var monthWorkoutCount: Int {
        daysInMonth.compactMap { $0 }.filter { workoutsByDay[calendar.startOfDay(for: $0)] != nil }.count
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpties = firstWeekday - calendar.firstWeekday
        let adjustedLeading = leadingEmpties < 0 ? leadingEmpties + 7 : leadingEmpties

        var days: [Date?] = Array(repeating: nil, count: adjustedLeading)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // Pad to fill last row
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    monthNavigation
                    calendarGrid
                    monthStats
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .sheet(item: $selectedLog) { log in
                WorkoutHistoryDetailSheet(log: log)
            }
        }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthTitle)
                .font(.headline.weight(.bold))
                .contentTransition(.numericText())

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? .quaternary : .primary)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 4)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.prefix(2).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // Day cells
            let rows = daysInMonth.chunked(into: 7)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(for: date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func dayCell(for date: Date) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let dayLogs = workoutsByDay[dayStart]
        let hasWorkout = dayLogs != nil
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()

        let isFullyCompleted = dayLogs?.allSatisfy { $0.exercisesCompleted == $0.totalExercises } ?? false

        return Button {
            if let logs = dayLogs, let first = logs.first {
                selectedLog = first
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isFuture ? .quaternary : .primary)

                if hasWorkout {
                    Circle()
                        .fill(isFullyCompleted ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Group {
                    if isToday {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1.5)
                            .frame(width: 40, height: 40)
                    }
                }
            )
        }
        .disabled(!hasWorkout)
        .buttonStyle(.plain)
    }

    // MARK: - Month Stats

    private var monthStats: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(monthWorkoutCount)",
                label: "This Month",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1, height: 36)

            statItem(
                value: "\(appState.profile.currentStreak)",
                label: "Day Streak",
                icon: "flame.fill",
                color: .orange
            )

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1, height: 36)

            statItem(
                value: "\(logs.count)",
                label: "All Time",
                icon: "trophy.fill",
                color: .purple
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
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
