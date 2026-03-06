import SwiftUI
import Charts

struct ScanHistoryGraphView: View {
    let entries: [ScanHistoryEntry]
    @State private var selectedEntry: ScanHistoryEntry? = nil

    private var sortedEntries: [ScanHistoryEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var latestScore: Double {
        sortedEntries.last?.overallScore ?? 0
    }

    private var scoreRange: ClosedRange<Double> {
        let scores = sortedEntries.map(\.overallScore)
        let minScore = max((scores.min() ?? 0) - 1.0, 0)
        let maxScore = min((scores.max() ?? 10) + 1.0, 10)
        return minScore...maxScore
    }

    private func lineColor(for score: Double) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return .yellow }
        return .orange
    }

    private var averageScore: Double {
        guard !sortedEntries.isEmpty else { return 5 }
        return sortedEntries.map(\.overallScore).reduce(0, +) / Double(sortedEntries.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Scan History")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if !entries.isEmpty {
                    Text("\(entries.count) scans")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if entries.isEmpty {
                emptyState
            } else {
                chartView
                    .frame(height: 200)

                if let selected = selectedEntry {
                    scanDetailCard(selected)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No scans yet")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var chartView: some View {
        Chart {
            ForEach(sortedEntries) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.overallScore)
                )
                .foregroundStyle(lineColor(for: averageScore))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.overallScore)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor(for: averageScore).opacity(0.2), lineColor(for: averageScore).opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.overallScore)
                )
                .foregroundStyle(selectedEntry?.id == entry.id ? .primary : lineColor(for: entry.overallScore))
                .symbolSize(selectedEntry?.id == entry.id ? 80 : 40)
                .annotation(position: .top, spacing: 4) {
                    if sortedEntries.count <= 5 || selectedEntry?.id == entry.id {
                        Text(String(format: "%.1f", entry.overallScore))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(lineColor(for: entry.overallScore))
                    }
                }
            }

            if sortedEntries.count == 1, let single = sortedEntries.first {
                RuleMark(y: .value("Score", single.overallScore))
                    .foregroundStyle(lineColor(for: single.overallScore).opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: scoreRange)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(sortedEntries.count, 5))) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel {
                    if let score = value.as(Double.self) {
                        Text(String(format: "%.0f", score))
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let frame = geo[plotFrame]
                        let xPosition = location.x - frame.origin.x

                        guard let tappedDate: Date = proxy.value(atX: xPosition) else { return }

                        let closest = sortedEntries.min(by: {
                            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                        })

                        withAnimation(.spring(duration: 0.3)) {
                            if selectedEntry?.id == closest?.id {
                                selectedEntry = nil
                            } else {
                                selectedEntry = closest
                            }
                        }
                    }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func scanDetailCard(_ entry: ScanHistoryEntry) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(entry.muscleMassRating)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", entry.overallScore))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(lineColor(for: entry.overallScore))
                    Text("/10")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 16) {
                if !entry.strongPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                            Text("Strengths")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.strongPoints.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                }

                if !entry.weakPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("Improve")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.weakPoints.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    selectedEntry = nil
                }
            } label: {
                Text("Dismiss")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(lineColor(for: entry.overallScore).opacity(0.15), lineWidth: 1)
        )
    }
}
