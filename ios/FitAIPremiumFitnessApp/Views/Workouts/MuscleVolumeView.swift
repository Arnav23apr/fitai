import SwiftUI
import Charts
import MuscleMap

/// Hevy/RP-style weekly volume dashboard. Counts working sets per
/// muscle group across a 7-day window and overlays Renaissance
/// Periodization MEV/MAV/MRV reference bands so the lifter can see
/// whether each muscle is undertrained, in the productive range, or
/// over the recoverable max.
struct MuscleVolumeView: View {
    @Environment(\.dismiss) private var dismiss

    enum WindowOption: String, CaseIterable, Identifiable {
        case thisWeek
        case lastWeek
        case last4WeekAvg

        var id: String { rawValue }
        var label: String {
            switch self {
            case .thisWeek: return "This Week"
            case .lastWeek: return "Last Week"
            case .last4WeekAvg: return "4-Week Avg"
            }
        }
    }

    @State private var window: WindowOption = .thisWeek

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    explainer

                    Picker("Window", selection: $window) {
                        ForEach(WindowOption.allCases) { opt in
                            Text(opt.label).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)

                    chartCard
                    legendCard
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Weekly Volume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sets per muscle per week")
                .font(.subheadline.weight(.semibold))
            Text("Bars are working sets only. Reference bands come from Renaissance Periodization volume landmarks: MEV (minimum effective), MAV (productive range), MRV (max recoverable).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if rows.isEmpty {
                Text("No working sets in the selected window.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Sets", row.setCount),
                        y: .value("Muscle", row.label)
                    )
                    .foregroundStyle(row.tier.color)
                    .annotation(position: .trailing) {
                        Text("\(row.setCount)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    if let mev = row.landmarks?.mev {
                        RuleMark(x: .value("MEV", mev))
                            .foregroundStyle(.gray.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    if let mrv = row.landmarks?.mrv {
                        RuleMark(x: .value("MRV", mrv))
                            .foregroundStyle(.red.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .frame(height: CGFloat(rows.count) * 32 + 24)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var legendCard: some View {
        HStack(spacing: 0) {
            legendCell(color: VolumeTier.under.color, label: "< MEV")
            legendCell(color: VolumeTier.productive.color, label: "MEV–MAV")
            legendCell(color: VolumeTier.maximum.color, label: "MAV–MRV")
            legendCell(color: VolumeTier.over.color, label: "> MRV")
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func legendCell(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private var rows: [VolumeRow] {
        let window = currentWindow
        let logs = ExerciseLogService.shared.loadAll()
            .filter { $0.date >= window.start && $0.date <= window.end }
        guard !logs.isEmpty else { return [] }

        var setsPerMuscle: [Muscle: Double] = [:]
        for log in logs {
            let workingSets = log.sets.filter(\.countsTowardVolume).count
            guard workingSets > 0 else { continue }
            let mapping = MuscleMapperService.shared.mapping(
                for: log.exerciseName,
                muscleGroup: log.muscleGroup
            )
            // Primary muscles get full set credit; secondaries get 0.5
            // each. Same convention RP-style trackers use to avoid
            // double-counting compounds (a bench press isn't 5 chest +
            // 5 triceps, it's 5 chest + 2.5 triceps for accounting).
            for m in mapping.primary {
                setsPerMuscle[m, default: 0] += Double(workingSets)
            }
            for m in mapping.secondary {
                setsPerMuscle[m, default: 0] += Double(workingSets) * 0.5
            }
        }

        // Average across weeks if window is multi-week.
        let weeks = max(1, window.weekCount)
        let normalized = setsPerMuscle.mapValues { $0 / Double(weeks) }

        return normalized
            .filter { $0.value > 0 }
            .map { (muscle, count) in
                let int = Int(count.rounded())
                let landmarks = VolumeLandmarks.for(muscle: muscle)
                let tier = VolumeTier.from(setCount: int, landmarks: landmarks)
                return VolumeRow(
                    muscle: muscle,
                    label: MuscleMapperService.shared.muscleToString(muscle),
                    setCount: int,
                    tier: tier,
                    landmarks: landmarks
                )
            }
            .sorted { $0.setCount > $1.setCount }
    }

    private var currentWindow: (start: Date, end: Date, weekCount: Int) {
        let cal = Calendar.current
        let now = Date()
        switch window {
        case .thisWeek:
            let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start, now, 1)
        case .lastWeek:
            let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let lastWeekStart = cal.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart
            let lastWeekEnd = cal.date(byAdding: .second, value: -1, to: thisWeekStart) ?? thisWeekStart
            return (lastWeekStart, lastWeekEnd, 1)
        case .last4WeekAvg:
            let start = cal.date(byAdding: .day, value: -28, to: now) ?? now
            return (start, now, 4)
        }
    }
}

private struct VolumeRow: Identifiable {
    var id: String { label }
    let muscle: Muscle
    let label: String
    let setCount: Int
    let tier: VolumeTier
    let landmarks: VolumeLandmarks?
}

private enum VolumeTier {
    case under
    case productive
    case maximum
    case over
    case unknown

    var color: Color {
        switch self {
        case .under: return .red
        case .productive: return .green
        case .maximum: return .yellow
        case .over: return .orange
        case .unknown: return .gray
        }
    }

    static func from(setCount: Int, landmarks: VolumeLandmarks?) -> VolumeTier {
        guard let l = landmarks else { return .unknown }
        if setCount < l.mev { return .under }
        if setCount < l.mav { return .productive }
        if setCount < l.mrv { return .maximum }
        return .over
    }
}

/// Renaissance Periodization volume landmarks (sets per muscle per week)
/// for the canonical major muscle groups. Numbers from Mike Israetel's
/// hypertrophy guidelines, rounded to integers for display.
private struct VolumeLandmarks {
    let mev: Int
    let mav: Int
    let mrv: Int

    static func `for`(muscle: Muscle) -> VolumeLandmarks? {
        switch muscle {
        case .chest:        return VolumeLandmarks(mev: 8,  mav: 16, mrv: 22)
        case .upperBack:    return VolumeLandmarks(mev: 10, mav: 18, mrv: 25)
        case .deltoids:     return VolumeLandmarks(mev: 8,  mav: 18, mrv: 26)
        case .biceps:       return VolumeLandmarks(mev: 8,  mav: 16, mrv: 26)
        case .triceps:      return VolumeLandmarks(mev: 6,  mav: 12, mrv: 18)
        case .quadriceps:   return VolumeLandmarks(mev: 8,  mav: 14, mrv: 20)
        case .hamstring:    return VolumeLandmarks(mev: 6,  mav: 12, mrv: 20)
        case .gluteal:      return VolumeLandmarks(mev: 4,  mav: 10, mrv: 16)
        case .calves:       return VolumeLandmarks(mev: 8,  mav: 14, mrv: 20)
        case .abs:          return VolumeLandmarks(mev: 6,  mav: 18, mrv: 25)
        case .obliques:     return VolumeLandmarks(mev: 4,  mav: 12, mrv: 20)
        case .lowerBack:    return VolumeLandmarks(mev: 4,  mav: 8,  mrv: 14)
        case .trapezius:    return VolumeLandmarks(mev: 6,  mav: 16, mrv: 26)
        case .forearm:      return VolumeLandmarks(mev: 4,  mav: 10, mrv: 16)
        default:            return nil
        }
    }
}
