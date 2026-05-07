import SwiftUI

struct ExerciseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let exercise: Exercise

    @State private var showHowTo: Bool = false

    private let logService = ExerciseLogService.shared
    private var demo: ExerciseDemoInfo { exercise.demoInfo }
    private var history: ExerciseHistory { logService.history(for: exercise.name) }

    private var lang: String { appState.profile.selectedLanguage }

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
                    Button(L.t("done", lang)) { dismiss() }
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
                Text(L.t("howToPerform", lang))
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [muscleAccent.opacity(0.30), muscleAccent.opacity(0.06)],
                            center: UnitPoint(x: 0.35, y: 0.30),
                            startRadius: 4,
                            endRadius: 60
                        )
                    )
                    .frame(width: 96, height: 96)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [muscleAccent.opacity(0.40), muscleAccent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: muscleIcon)
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [muscleAccent, muscleAccent.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: muscleAccent.opacity(0.35), radius: 8, y: 3)
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
                    .foregroundStyle(muscleAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(muscleAccent.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.03))
                LinearGradient(
                    colors: [muscleAccent.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: 20))
            }
        )
    }

    // MARK: - Muscles

    private var muscleChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !demo.primaryMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(L.t("primaryLabel", lang))
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
                    Text(L.t("secondaryLabel", lang))
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
                Text(L.t("howToPerform", lang))
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
                Text(L.t("proTipsLabel", lang))
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
                Text(L.t("yourHistory", lang))
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
                statBox(label: L.t("bestShort", lang), value: "\(Int(history.personalBestWeight))", unit: appState.profile.usesMetric ? "kg" : "lbs", color: .purple)
                Spacer()
                statBox(label: L.t("bestRepsLabel", lang), value: "\(history.personalBestReps)", unit: L.t("repsUnit", lang), color: .blue)
                Spacer()
                statBox(label: L.t("sessionsLabel", lang), value: "\(history.logs.count)", unit: nil, color: .green)
            }

            if history.isPRReady {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text(L.t("closeToPRMsg", lang))
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
                        Text(L.t("progressiveOverload", lang))
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
        let name = exercise.name.lowercased()
        let group = exercise.muscleGroup.lowercased()

        if name.contains("squat") || name.contains("lunge") { return "figure.strengthtraining.functional" }
        if name.contains("deadlift") { return "figure.strengthtraining.traditional" }
        if name.contains("row") || name.contains("pulldown") { return "figure.rowing" }
        if name.contains("pull-up") || name.contains("pullup") || name.contains("chin") { return "figure.climbing" }
        if name.contains("press") || name.contains("bench") { return "figure.strengthtraining.traditional" }
        if name.contains("curl") { return "dumbbell.fill" }
        if name.contains("plank") || name.contains("crunch") || name.contains("sit-up") { return "figure.core.training" }
        if name.contains("run") || name.contains("sprint") || name.contains("jog") { return "figure.run" }
        if name.contains("jump") || name.contains("box jump") { return "figure.jumprope" }
        if name.contains("kick") || name.contains("punch") || name.contains("box") { return "figure.boxing" }
        if name.contains("yoga") || name.contains("stretch") { return "figure.yoga" }

        if group.contains("chest") { return "figure.strengthtraining.traditional" }
        if group.contains("back") || group.contains("lat") { return "figure.rowing" }
        if group.contains("shoulder") || group.contains("delt") { return "figure.boxing" }
        if group.contains("bicep") || group.contains("tricep") || group.contains("arm") { return "dumbbell.fill" }
        if group.contains("quad") || group.contains("hamstring") || group.contains("glute") || group.contains("leg") || group.contains("calv") { return "figure.strengthtraining.functional" }
        if group.contains("core") || group.contains("abs") || group.contains("oblique") { return "figure.core.training" }
        return "dumbbell.fill"
    }

    private var muscleAccent: Color {
        let group = exercise.muscleGroup.lowercased()
        if group.contains("chest") { return Color(red: 1.00, green: 0.32, blue: 0.40) }
        if group.contains("back") || group.contains("lat") { return Color(red: 0.20, green: 0.55, blue: 1.00) }
        if group.contains("shoulder") || group.contains("delt") { return Color(red: 0.35, green: 0.45, blue: 1.00) }
        if group.contains("bicep") || group.contains("tricep") || group.contains("arm") { return Color(red: 0.85, green: 0.40, blue: 0.95) }
        if group.contains("quad") || group.contains("hamstring") || group.contains("glute") || group.contains("leg") || group.contains("calv") { return Color(red: 0.20, green: 0.75, blue: 0.50) }
        if group.contains("core") || group.contains("abs") || group.contains("oblique") { return Color(red: 1.00, green: 0.62, blue: 0.10) }
        return .blue
    }

    private var trendLabel: String {
        switch history.volumeTrend {
        case .up: return L.t("trendImproving", lang)
        case .down: return L.t("trendDeclining", lang)
        case .neutral: return L.t("trendSteady", lang)
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

