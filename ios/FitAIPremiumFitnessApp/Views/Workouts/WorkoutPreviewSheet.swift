import SwiftUI

/// Pre-flight screen between tapping a routine card and entering
/// ActiveSessionView. Until this existed, a tap dumped the user straight
/// into logging mode, which made it impossible to:
///   - Confirm what the workout actually contains before committing
///   - See estimated duration / muscle coverage
///   - Edit or back out without "discarding"
///
/// Visual language: matches the app's indigo/purple gradient cards
/// (`RoutineCardGlass`, `GradientCardBackground`) so the preview feels
/// like a richer version of the source routine card it expanded from.
struct WorkoutPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let routine: Routine
    let onStart: () -> Void
    /// Optional secondary action — when set, the sheet shows a small "Edit"
    /// chip in the header that fires this callback (typically opens the
    /// routine editor). nil hides the chip.
    var onEdit: (() -> Void)? = nil

    /// Drives the per-row how-to sheet. Routes straight to
    /// `ExerciseHowToSheet` (looping video + form cues + tips) instead of
    /// the intermediate `ExerciseDemoSheet` step — the user only ever
    /// wanted the video page, the demo sheet was an extra hop.
    @State private var howToExerciseName: String? = nil

    private var lang: String { appState.profile.selectedLanguage }

    /// Map an exercise's muscle group string to an SF Symbol. Falls back to
    /// a generic dumbbell when we don't have a confident match. Comparing
    /// lowercased substrings keeps the matcher tolerant of variants like
    /// "Mid Back" / "Lower Back" / "Upper Chest".
    private func iconForMuscleGroup(_ group: String) -> String {
        let g = group.lowercased()
        if g.contains("chest")    { return "figure.arms.open" }
        if g.contains("back")     { return "figure.strengthtraining.traditional" }
        if g.contains("shoulder") || g.contains("delt") { return "figure.boxing" }
        if g.contains("bicep") || g.contains("tricep") || g.contains("arm") { return "dumbbell.fill" }
        if g.contains("forearm")  { return "hand.raised.fill" }
        if g.contains("quad") || g.contains("hamstring") || g.contains("leg") { return "figure.run" }
        if g.contains("calf") || g.contains("calves") { return "figure.walk" }
        if g.contains("glute")    { return "figure.cooldown" }
        if g.contains("core") || g.contains("abs") { return "figure.core.training" }
        if g.contains("cardio") || g.contains("heart") { return "heart.fill" }
        return "dumbbell.fill"
    }

    private var totalSets: Int {
        routine.exercises.reduce(0) { $0 + $1.sets }
    }

    /// Rough estimate: each set ≈ 35s of work, then routine.defaultRestSeconds
    /// between sets. Not exact — the user's logged times will vary — but it
    /// gives a useful "this is a 45-min session" sense before starting.
    private var estimatedMinutes: Int {
        let workSeconds = totalSets * 35
        let restSeconds = max(0, totalSets - routine.exercises.count) * routine.defaultRestSeconds
        let total = workSeconds + restSeconds
        return max(5, Int((Double(total) / 60.0).rounded()))
    }

    /// Deduped muscle-group list with empty/blank strings filtered. Capped
    /// at 3 for the header chip row; full coverage shows on each exercise.
    private var primaryMuscleGroups: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for ex in routine.exercises {
            let m = ex.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !m.isEmpty else { continue }
            let key = m.lowercased()
            if seen.insert(key).inserted {
                result.append(m.capitalized)
            }
            if result.count >= 3 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroBlock
                    statsStrip
                    exerciseList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // room for sticky CTA
            }
            .background(pageBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                }
                if let onEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onEdit()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                                Text(L.t("edit", lang))
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, 10)
                    .background(.regularMaterial)
            }
            // Identifiable wrapper inline — String isn't Identifiable, so
            // we wrap on the fly for `.sheet(item:)`. Dismiss writes nil
            // back through the binding so the sheet closes cleanly.
            .sheet(item: Binding(
                get: { howToExerciseName.map(HowToTarget.init(name:)) },
                set: { howToExerciseName = $0?.name }
            )) { target in
                // Skip ExerciseDemoSheet entirely — go straight to the
                // video + written guide view. Need a transient Exercise
                // wrapper since ExerciseHowToSheet expects the full type
                // (sets/reps fields are unused in that view).
                ExerciseHowToSheet(
                    exercise: Exercise(name: target.name, sets: 0, reps: "", muscleGroup: "")
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private struct HowToTarget: Identifiable {
        let name: String
        var id: String { name }
    }

    // MARK: - Page background

    /// Subtle indigo wash radiating from the top — matches the gradient
    /// language used elsewhere (RoutineCardGlass, EmptyStateGlass) so the
    /// preview reads as part of the same world as the source card.
    private var pageBackground: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.10),
                    Color.purple.opacity(0.04),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero block

    private var heroBlock: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.30),
                                Color.purple.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                Image(systemName: routine.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: Color.indigo.opacity(0.25), radius: 18, y: 6)

            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                if let folder = routine.folder, !folder.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(folder)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if !primaryMuscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(primaryMuscleGroups, id: \.self) { group in
                        Text(group)
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(.primary.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [Color.indigo.opacity(0.20), Color.purple.opacity(0.12)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.indigo.opacity(0.20), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stats strip

    /// Four-up: exercise count, total sets, est duration, default rest.
    /// Each tile is a mini gradient card so the row reads as one cohesive
    /// block instead of four flat pills.
    private var statsStrip: some View {
        HStack(spacing: 8) {
            statTile(value: "\(routine.exercises.count)",
                     label: routine.exercises.count == 1 ? "exercise" : "exercises",
                     icon: "list.bullet")
            statTile(value: "\(totalSets)",
                     label: totalSets == 1 ? "set" : "sets",
                     icon: "square.stack")
            statTile(value: "\(estimatedMinutes)m",
                     label: "est",
                     icon: "clock.fill")
            statTile(value: "\(routine.defaultRestSeconds)s",
                     label: "rest",
                     icon: "timer")
        }
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.indigo.opacity(0.85))
            Text(value)
                .font(.system(.body, design: .rounded, weight: .heavy))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.08),
                        Color.purple.opacity(0.03),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.indigo.opacity(0.14), lineWidth: 0.5)
        )
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EXERCISES")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)

            VStack(spacing: 8) {
                ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { idx, exercise in
                    exerciseRow(exercise, index: idx + 1)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: RoutineExercise, index: Int) -> some View {
        Button {
            howToExerciseName = exercise.name
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // Muscle-group icon badge. Replaced the order number — order
                // is implicit from list position; muscle group is the higher
                // -signal info ("oh that's a back row, that's biceps...").
                // The badge keeps the same indigo→purple gradient so the
                // visual rhythm of the list is preserved.
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.indigo.opacity(0.22),
                                    Color.purple.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: iconForMuscleGroup(exercise.muscleGroup))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.indigo, Color.purple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if let group = exercise.supersetGroup {
                            Text("SS\(group)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.indigo, in: Capsule())
                        }
                    }
                    HStack(spacing: 6) {
                        Text("\(exercise.sets) × \(exercise.reps)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if !exercise.muscleGroup.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(exercise.muscleGroup.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let rpe = exercise.targetRPE {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("@\(rpe)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }
                    if !exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(exercise.notes)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)

                // Info button. Blue (the universal "info" semantic) and
                // vertically centered in the row. The whole row is still
                // the hit target — this just reads as a proper info
                // affordance instead of a faded grey hint.
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.blue)
                    .accessibilityLabel("How to perform")
            }
            .padding(12)
            .gradientCard(tint: .indigo, cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: howToExerciseName == exercise.name)
    }

    // MARK: - Start button

    private var startButton: some View {
        Button {
            onStart()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text("Start Workout")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.indigo, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: Color.indigo.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: false)
    }
}
