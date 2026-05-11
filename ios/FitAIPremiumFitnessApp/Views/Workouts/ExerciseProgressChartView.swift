import SwiftUI
import Charts

/// Hevy / Strong-style per-exercise progress chart. Toggle between four
/// metrics (best weight, est-1RM, total volume, total reps) and four
/// time ranges (1M, 3M, 6M, 1Y). Pulls history from `ExerciseLogService`
/// and aggregates to one data point per session. Empty-state handles
/// new exercises with zero history. Uses SwiftUI Charts (iOS 16+).
struct ExerciseProgressChartView: View {
    let exerciseName: String
    let usesMetric: Bool

    enum Metric: String, CaseIterable, Identifiable {
        case bestWeight
        case estimatedOneRM
        case volume
        case totalReps

        var id: String { rawValue }
        var label: String {
            switch self {
            case .bestWeight: return "Best Weight"
            case .estimatedOneRM: return "Est. 1RM"
            case .volume: return "Volume"
            case .totalReps: return "Total Reps"
            }
        }
        var shortLabel: String {
            switch self {
            case .bestWeight: return "Weight"
            case .estimatedOneRM: return "1RM"
            case .volume: return "Volume"
            case .totalReps: return "Reps"
            }
        }
        var color: Color {
            switch self {
            case .bestWeight: return .purple
            case .estimatedOneRM: return .orange
            case .volume: return .blue
            case .totalReps: return .green
            }
        }
        var systemImage: String {
            switch self {
            case .bestWeight: return "scalemass.fill"
            case .estimatedOneRM: return "flame.fill"
            case .volume: return "chart.bar.fill"
            case .totalReps: return "repeat"
            }
        }
    }

    enum Range: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        var id: String { rawValue }
        var days: Int {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            }
        }
    }

    @State private var metric: Metric = .bestWeight
    @State private var range: Range = .threeMonths

    private var allLogs: [ExerciseLog] {
        ExerciseLogService.shared.history(for: exerciseName).logs
            .sorted { $0.date < $1.date }
    }

    private var filteredLogs: [ExerciseLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date.distantPast
        return allLogs.filter { $0.date >= cutoff }
    }

    private var dataPoints: [ChartPoint] {
        filteredLogs.map { log in
            ChartPoint(
                date: log.date,
                value: metricValue(for: log)
            )
        }
    }

    private var unitLabel: String {
        switch metric {
        case .bestWeight, .estimatedOneRM: return usesMetric ? "kg" : "lbs"
        case .volume: return usesMetric ? "kg" : "lbs"
        case .totalReps: return "reps"
        }
    }

    private var bestPoint: ChartPoint? {
        dataPoints.max { $0.value < $1.value }
    }

    private var latestPoint: ChartPoint? { dataPoints.last }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metricPicker
                rangePicker
                chartCard
                summaryStats
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Metric.allCases) { m in
                    Button {
                        metric = m
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: m.systemImage)
                                .font(.system(size: 11, weight: .heavy))
                            Text(m.label)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(metric == m ? .white : m.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(metric == m ? m.color : m.color.opacity(0.12))
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(Range.allCases) { r in
                Text(r.rawValue).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chartCard: some View {
        if dataPoints.count < 2 {
            emptyState
        } else {
            chartBody
        }
    }

    private var chartBody: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.shortLabel, point.value)
            )
            .foregroundStyle(metric.color.gradient)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            AreaMark(
                x: .value("Date", point.date),
                y: .value(metric.shortLabel, point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [metric.color.opacity(0.30), metric.color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.shortLabel, point.value)
            )
            .foregroundStyle(metric.color)
            .symbolSize(20)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 240)
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var summaryStats: some View {
        HStack(spacing: 0) {
            statBlock(
                label: "Best",
                value: bestPoint.map { format($0.value) } ?? "-",
                unit: unitLabel,
                color: metric.color
            )
            Divider().frame(height: 36)
            statBlock(
                label: "Latest",
                value: latestPoint.map { format($0.value) } ?? "-",
                unit: unitLabel,
                color: .secondary
            )
            Divider().frame(height: 36)
            statBlock(
                label: "Sessions",
                value: "\(filteredLogs.count)",
                unit: nil,
                color: .green
            )
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func statBlock(label: String, value: String, unit: String?, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(color)
                if let unit {
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(filteredLogs.isEmpty
                 ? "No history in the last \(range.rawValue)"
                 : "Need at least 2 sessions to draw a trend")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func metricValue(for log: ExerciseLog) -> Double {
        switch metric {
        case .bestWeight:
            return log.bestSetWeight
        case .estimatedOneRM:
            return log.bestEstimatedOneRM
        case .volume:
            return log.computedVolume
        case .totalReps:
            return Double(log.sets.filter(\.countsTowardVolume).map(\.reps).reduce(0, +))
        }
    }

    private func format(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        return value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
