import SwiftUI

/// Densification cards for the Workouts hub that only render once the
/// user has enough history to have something meaningful to look at.
/// Shown after 5+ logged sessions across the lifetime of the account.
/// Two cards:
///   1. This week's working-set volume vs. last week (delta + chart hint)
///   2. Next PR opportunity (closest exercise to a weight PR)
///
/// Computed lazily on every render from `ExerciseLogService.loadAll()`.
/// Cheap because the dataset is bounded to ~500 logs by design.
struct PowerUserInsightsSection: View {
    let usesMetric: Bool
    let onTapExercise: (String) -> Void

    private let logService = ExerciseLogService.shared
    private let calendar = Calendar.current

    private var allLogs: [ExerciseLog] { logService.loadAll() }

    /// Hub-densification gate. Below 5 sessions there isn't enough
    /// signal to make either card useful.
    private var sessionCount: Int { allLogs.count }
    private var shouldShow: Bool { sessionCount >= 5 }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Insights")
                        .font(.title3.weight(.bold))
                    Spacer()
                }

                HStack(spacing: 10) {
                    weeklyVolumeCard
                    if let pr = nextPROpportunity() {
                        prOpportunityCard(pr)
                    } else {
                        emptyPRCard
                    }
                }
            }
        }
    }

    // MARK: - Weekly volume card

    private var weeklyVolumeCard: some View {
        let now = Date()
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart

        let thisWeekSets = workingSetCount(from: thisWeekStart, to: now)
        let lastWeekSets = workingSetCount(from: lastWeekStart, to: thisWeekStart)
        let delta = thisWeekSets - lastWeekSets
        let trend: Trend = delta > 0 ? .up : (delta < 0 ? .down : .flat)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.blue)
                Text("This week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(thisWeekSets)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("sets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.system(size: 10, weight: .heavy))
                Text(deltaText(delta: delta, trend: trend))
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(trend.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Next PR opportunity card

    private func prOpportunityCard(_ pr: PROpportunity) -> some View {
        Button {
            onTapExercise(pr.name)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.orange)
                    Text("Next PR")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(pr.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text("\(Int(pr.lastBest))")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.orange)
                    Text("→")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.tertiary)
                    Text("\(Int(pr.target))")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text(usesMetric ? "kg" : "lbs")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyPRCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.orange.opacity(0.5))
                Text("Next PR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("Log a few more sessions to surface PR opportunities.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Compute helpers

    /// Sum of working (non-warmup) sets between two dates, completed only.
    private func workingSetCount(from start: Date, to end: Date) -> Int {
        var n = 0
        for log in allLogs where log.date >= start && log.date <= end {
            n += log.sets.filter(\.countsTowardVolume).count
        }
        return n
    }

    /// Find the exercise where the lifter's most recent best set is
    /// closest to (but below) their all-time PR. The "next bump" weight
    /// nudges them toward breaking it. We look for the last 30 days of
    /// activity so we don't surface stale exercises.
    private func nextPROpportunity() -> PROpportunity? {
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        let recentNames = Set(allLogs.filter { $0.date >= cutoff }.map(\.exerciseName))

        struct Candidate {
            let name: String
            let lastBest: Double
            let allTimeBest: Double
            var ratio: Double { lastBest / allTimeBest }
        }

        var candidates: [Candidate] = []
        for name in recentNames {
            let history = logService.history(for: name)
            guard let last = history.lastSession else { continue }
            let lastBest = last.bestSetWeight
            let allTime = history.personalBestWeight
            // Must be within 10% of the all-time PR but not yet broken.
            guard allTime > 0, lastBest > 0,
                  lastBest >= allTime * 0.90,
                  lastBest < allTime else { continue }
            candidates.append(Candidate(name: name, lastBest: lastBest, allTimeBest: allTime))
        }

        guard let pick = candidates.max(by: { $0.ratio < $1.ratio }) else { return nil }
        // "Next bump" target: last best + 5 lb / 2.5 kg, rounded down
        // toward the all-time PR if exceeding it.
        let increment: Double = usesMetric ? 2.5 : 5.0
        let target = min(pick.lastBest + increment, pick.allTimeBest)
        return PROpportunity(name: pick.name, lastBest: pick.lastBest, target: target)
    }

    private func deltaText(delta: Int, trend: Trend) -> String {
        switch trend {
        case .up: return "+\(delta) vs last week"
        case .down: return "\(delta) vs last week"
        case .flat: return "Same as last week"
        }
    }
}

private struct PROpportunity {
    let name: String
    let lastBest: Double
    let target: Double
}

private enum Trend {
    case up, down, flat
    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "minus"
        }
    }
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .flat: return .secondary
        }
    }
}
