import SwiftUI

/// In-session "how do I do this exercise?" half-sheet. Trimmed version
/// of ExerciseDetailSheet for users mid-workout: shows the how-to video
/// button (if media exists), step-by-step form cues, primary/secondary
/// muscles, and last session's best set. Half-sheet detent so the
/// active session stays visible underneath, the lifter scrubs the
/// video, then dismisses with a swipe and logs the next set.
struct ExerciseDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let exerciseName: String

    @State private var showHowTo: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var usesMetric: Bool { appState.profile.usesMetric }

    /// Build a transient `Exercise` to pull `demoInfo` and the
    /// existing `ExerciseHowToSheet` plumbing without touching its
    /// shape. Sets/reps fields don't matter here.
    private var exercise: Exercise {
        Exercise(name: exerciseName, sets: 0, reps: "", muscleGroup: "")
    }

    private var demo: ExerciseDemoInfo { exercise.demoInfo }

    private var lastSession: ExerciseLog? {
        ExerciseLogService.shared.lastSession(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    titleHeader
                    if demo.hasMedia {
                        howToButton
                    } else {
                        noMediaNotice
                    }
                    if !demo.instructions.isEmpty {
                        instructionsBlock
                    }
                    if !demo.tips.isEmpty {
                        tipsBlock
                    }
                    musclesBlock
                    if let last = lastSession {
                        lastSessionBlock(last)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("How to perform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showHowTo) {
                ExerciseHowToSheet(exercise: exercise)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Subviews

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exerciseName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private var howToButton: some View {
        Button { showHowTo = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Watch how-to video")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.blue, Color.blue.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: .blue.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var noMediaNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text("No video available for this exercise yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var instructionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Form cues", systemImage: "checklist")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(demo.instructions.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.blue))
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Tips", systemImage: "lightbulb.fill")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(demo.tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.orange)
                            .padding(.top, 7)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var musclesBlock: some View {
        if !demo.primaryMuscles.isEmpty || !demo.secondaryMuscles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Muscles worked", systemImage: "figure.strengthtraining.traditional")
                if !demo.primaryMuscles.isEmpty {
                    musclePillRow(label: "Primary", names: demo.primaryMuscles, color: .red)
                }
                if !demo.secondaryMuscles.isEmpty {
                    musclePillRow(label: "Secondary", names: demo.secondaryMuscles, color: .orange)
                }
            }
        }
    }

    private func musclePillRow(label: String, names: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            FlowingTagWrap(tags: names, color: color)
        }
    }

    private func lastSessionBlock(_ log: ExerciseLog) -> some View {
        let bestWeight = log.bestSetWeight
        let bestReps = log.bestSetReps
        let unit = usesMetric ? "kg" : "lbs"
        let estOneRM = log.bestEstimatedOneRM
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Last session", systemImage: "clock.arrow.circlepath")
            HStack(spacing: 0) {
                lastSessionStat(value: "\(Int(bestWeight))", unit: unit, label: "Best", color: .purple)
                Divider().frame(height: 32)
                lastSessionStat(value: "\(bestReps)", unit: "reps", label: "Reps", color: .blue)
                if estOneRM > 0 {
                    Divider().frame(height: 32)
                    lastSessionStat(value: "\(Int(estOneRM))", unit: unit, label: "Est 1RM", color: .orange)
                }
            }
            Text(formatter.string(from: log.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func lastSessionStat(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(0.4)
        }
    }
}

/// Simple wrapping pill row using `DemoTagFlow`. Falls back to lazy
/// horizontal stack on iOS versions without native flow support.
private struct FlowingTagWrap: View {
    let tags: [String]
    let color: Color

    var body: some View {
        DemoTagFlow(spacing: 6) {
            ForEach(tags, id: \.self) { name in
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
    }
}

/// Minimal flow layout (left-to-right wrapping). iOS 16+.
private struct DemoTagFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let trial = rowWidths.last! + (rowWidths.last! > 0 ? spacing : 0) + size.width
            if trial > maxWidth {
                rowWidths.append(size.width)
                rowHeights.append(size.height)
            } else {
                rowWidths[rowWidths.count - 1] = trial
                rowHeights[rowHeights.count - 1] = max(rowHeights.last!, size.height)
            }
        }
        let totalHeight = rowHeights.reduce(0, +) + spacing * CGFloat(max(0, rowHeights.count - 1))
        let width = rowWidths.max() ?? 0
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x - bounds.minX > 0 && (x - bounds.minX + spacing + size.width) > maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
