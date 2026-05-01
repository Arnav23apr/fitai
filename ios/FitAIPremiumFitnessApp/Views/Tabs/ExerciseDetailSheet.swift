import SwiftUI

struct ExerciseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let exercise: Exercise

    @State private var showHowTo: Bool = false

    private let logService = ExerciseLogService.shared
    private var demo: ExerciseDemoInfo { exercise.demoInfo }
    private var history: ExerciseHistory { logService.history(for: exercise.name) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    exerciseHeader

                    if demo.hasMedia {
                        howToButton
                    }

                    muscleChips

                    if !demo.hasMedia {
                        // Fallback: when there's nothing to demo, surface the
                        // form cues inline so the user isn't left without them.
                        if !demo.instructions.isEmpty { instructionsCard }
                        if !demo.tips.isEmpty { tipsCard }
                    }

                    if history.logs.count > 0 {
                        historyCard
                    }

                    overloadSuggestionCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showHowTo) {
                ExerciseHowToSheet(exercise: exercise)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var howToButton: some View {
        Button { showHowTo = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("How to perform")
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
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: muscleIcon)
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 4) {
                Text(exercise.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("\(exercise.sets) sets \u{00B7} \(exercise.reps) reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !exercise.muscleGroup.isEmpty {
                Text(exercise.muscleGroup)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - Muscles

    private var muscleChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !demo.primaryMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("Primary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                FlowLayout(spacing: 8) {
                    ForEach(demo.primaryMuscles, id: \.self) { muscle in
                        Text(muscle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(.capsule)
                    }
                }
            }

            if !demo.secondaryMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                    Text("Secondary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                FlowLayout(spacing: 8) {
                    ForEach(demo.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(.capsule)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Instructions

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                Text("How To Perform")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(demo.instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.blue)
                            .clipShape(Circle())

                        Text(instruction)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.blue.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.blue.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Tips

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text("Pro Tips")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(demo.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .padding(.top, 1)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.yellow.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.yellow.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13))
                    .foregroundStyle(.purple)
                Text("Your History")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: history.volumeTrend.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(trendLabel)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(trendColor)
            }

            HStack(spacing: 0) {
                statBox(label: "Best", value: "\(Int(history.personalBestWeight))", unit: appState.profile.usesMetric ? "kg" : "lbs", color: .purple)
                Spacer()
                statBox(label: "Best Reps", value: "\(history.personalBestReps)", unit: "reps", color: .blue)
                Spacer()
                statBox(label: "Sessions", value: "\(history.logs.count)", unit: nil, color: .green)
            }

            if history.isPRReady {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("You're close to a new PR! Push a little harder today.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.purple.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.08), lineWidth: 1)
        )
    }

    private func statBox(label: String, value: String, unit: String?, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Overload Suggestion

    private var overloadSuggestionCard: some View {
        Group {
            if let suggestion = progressiveSuggestion {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text("Progressive Overload")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.green.opacity(0.06))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.green.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Helpers

    private var muscleIcon: String {
        let group = exercise.muscleGroup.lowercased()
        if group.contains("chest") { return "figure.strengthtraining.traditional" }
        if group.contains("back") || group.contains("lat") { return "figure.rowing" }
        if group.contains("shoulder") || group.contains("delt") { return "figure.boxing" }
        if group.contains("bicep") || group.contains("tricep") || group.contains("arm") { return "figure.mixed.cardio" }
        if group.contains("quad") || group.contains("hamstring") || group.contains("glute") || group.contains("leg") || group.contains("calv") { return "figure.run" }
        if group.contains("core") || group.contains("abs") || group.contains("oblique") { return "figure.core.training" }
        return "dumbbell.fill"
    }

    private var trendLabel: String {
        switch history.volumeTrend {
        case .up: return "Improving"
        case .down: return "Declining"
        case .neutral: return "Steady"
        }
    }

    private var trendColor: Color {
        switch history.volumeTrend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .secondary
        }
    }

    private var progressiveSuggestion: String? {
        guard history.logs.count > 0 else { return nil }
        let usesMetric = appState.profile.usesMetric
        let unit = usesMetric ? "kg" : "lbs"
        let increment = usesMetric ? 2.5 : 5.0
        let bestWeight = history.personalBestWeight

        if let last = history.lastSession {
            let lastBest = last.bestSetWeight

            if history.isPRReady {
                let target = bestWeight + increment
                return "You hit \(Int(lastBest))\(unit) last time \u{2014} your PR is \(Int(bestWeight))\(unit). Try \(formatWeight(target))\(unit) today to set a new personal record!"
            }

            if history.volumeTrend == .up {
                let target = lastBest + increment
                return "You're trending up! Try \(formatWeight(target))\(unit) this session \u{2014} a small \(formatWeight(increment))\(unit) jump from your last best."
            }

            if history.volumeTrend == .neutral && history.logs.count >= 3 {
                return "You've been at \(Int(lastBest))\(unit) for a few sessions. Try adding \(formatWeight(increment))\(unit) or aim for 1-2 extra reps per set."
            }

            if history.volumeTrend == .down {
                return "Focus on hitting \(Int(lastBest))\(unit) with solid form before increasing. Recovery and sleep matter \u{2014} you've got this."
            }

            let target = lastBest + increment
            return "Last session you lifted \(Int(lastBest))\(unit). Try \(formatWeight(target))\(unit) to keep progressing."
        }

        return nil
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}

