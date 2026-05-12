import SwiftUI

/// One Strong-style exercise block: name + ⋯ menu, set table, +Add Set.
struct ExerciseCard: View {
    @Binding var exercise: SessionExercise
    let weightUnit: String
    let defaultRest: Int
    @Binding var focusedField: FieldFocus?
    let editingText: String
    let onTapSetNumber: (String) -> Void
    let onSetCompleted: (String, Bool) -> Void
    let onRemoveExercise: () -> Void
    /// Tint for the colored left bar that visually groups exercises in
    /// the same superset. nil = no superset, no bar shown.
    var supersetColor: Color? = nil
    /// Optional letter suffix shown next to the exercise name (A / B / C…)
    /// for exercises in a superset, matching how Strong/Hevy label them.
    var supersetLetter: String? = nil
    /// Action called when the user picks "Add to superset" from the
    /// menu. Owner (ActiveSessionView) shows the picker sheet.
    var onTapSuperset: (() -> Void)? = nil
    /// Action called when the user picks "Replace exercise" from the
    /// menu. Owner shows the ExercisePickerSheet and swaps in place.
    var onReplaceExercise: (() -> Void)? = nil

    @State private var pinnedNote: String = ""
    @State private var showNoteEditor: Bool = false
    @State private var showWarmupCalculator: Bool = false
    @State private var showProgressChart: Bool = false
    @State private var showDemo: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Superset color rail. Visually groups consecutive exercises
            // in the same superset using a colored vertical bar — a
            // cleaner pattern than indentation, copying Dropset's UI.
            if let color = supersetColor {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 4)
                    .padding(.trailing, 8)
            }
            cardContent
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                if let letter = supersetLetter {
                    Text(letter)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(supersetColor ?? Color.indigo)
                        .clipShape(Circle())
                }
                Button {
                    showDemo = true
                } label: {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                bodyweightPill
                Menu {
                    Button {
                        showDemo = true
                    } label: {
                        Label("How to perform", systemImage: "play.circle")
                    }
                    Button {
                        showProgressChart = true
                    } label: {
                        Label("View progress chart", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    if let onReplaceExercise = onReplaceExercise {
                        Button {
                            onReplaceExercise()
                        } label: {
                            Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    if let onTapSuperset = onTapSuperset {
                        Button {
                            onTapSuperset()
                        } label: {
                            Label(
                                exercise.supersetGroup == nil ? "Add to superset" : "Change superset",
                                systemImage: "link"
                            )
                        }
                    }
                    Button {
                        showWarmupCalculator = true
                    } label: {
                        Label("Add warmup sets", systemImage: "flame")
                    }
                    Button {
                        showNoteEditor = true
                    } label: {
                        Label(pinnedNote.isEmpty ? "Add pinned note" : "Edit pinned note",
                              systemImage: "pin.fill")
                    }
                    if !pinnedNote.isEmpty {
                        Button(role: .destructive) {
                            ExerciseNoteService.shared.clearPinnedNote(for: exercise.name)
                            pinnedNote = ""
                        } label: {
                            Label("Remove pinned note", systemImage: "pin.slash")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        onRemoveExercise()
                    } label: {
                        Label("Remove exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 24)
                        .background(Color.blue.opacity(0.25))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }

            // Yellow pinned-note banner. Strong's convention: yellow is
            // reserved exclusively for pinned content the lifter wants
            // to remember every session ("set bench to position 4").
            if !pinnedNote.isEmpty {
                pinnedNoteBanner
            }

            // Header row matching Strong: Set | Previous | weight | Reps | ✓
            HStack(spacing: 0) {
                Text("Set")
                    .frame(width: 36, alignment: .center)
                Text("Previous")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(weightUnit)
                    .frame(width: 70, alignment: .center)
                Text("Reps")
                    .frame(width: 60, alignment: .center)
                    .padding(.leading, 6)
                Image(systemName: "checkmark")
                    .frame(width: 36, alignment: .center)
                    .padding(.leading, 6)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach($exercise.sets) { $set in
                VStack(spacing: 0) {
                    if shouldShowBumpSuggestion(for: set) {
                        bumpSuggestionBanner(for: $set)
                    }
                    SetRow(
                        set: $set,
                        focusedField: $focusedField,
                        editingText: editingText,
                        onTapSetNumber: { onTapSetNumber(set.id) },
                        onToggleComplete: {
                            // If marking complete with empty fields,
                            // accept any visible suggestion as the actual
                            // logged value. This is the "tap ✓ to accept
                            // last session's numbers" affordance.
                            if !$set.wrappedValue.isCompleted {
                                if $set.wrappedValue.weight == 0,
                                   $set.wrappedValue.previousWeight > 0 {
                                    $set.wrappedValue.weight = $set.wrappedValue.previousWeight
                                }
                                if $set.wrappedValue.reps == 0,
                                   $set.wrappedValue.previousReps > 0 {
                                    $set.wrappedValue.reps = $set.wrappedValue.previousReps
                                }
                            }
                            $set.wrappedValue.isCompleted.toggle()
                            onSetCompleted(set.id, $set.wrappedValue.isCompleted)
                        }
                    )
                }
            }

            Button {
                addSet()
            } label: {
                Text("+ Add Set")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        // Gradient card matches the design language of the routine list
        // and WorkoutPreviewSheet (indigo→purple wash + hairline) so the
        // exercise blocks read as kin to the cards the user just came
        // from, instead of being flat grey rectangles in a vacuum.
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.10),
                        Color.purple.opacity(0.04),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.16), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .onAppear {
            pinnedNote = ExerciseNoteService.shared.pinnedNote(for: exercise.name)
            syncBodyweightFlagToClassification()
        }
        .sheet(isPresented: $showNoteEditor) {
            PinnedNoteEditorSheet(
                exerciseName: exercise.name,
                initialText: pinnedNote,
                onSave: { newText in
                    ExerciseNoteService.shared.setPinnedNote(newText, for: exercise.name)
                    pinnedNote = newText
                    showNoteEditor = false
                },
                onCancel: { showNoteEditor = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWarmupCalculator) {
            WarmupCalculatorSheet(
                exerciseName: exercise.name,
                workingWeight: detectWorkingWeight(),
                isMetric: weightUnit.lowercased().contains("kg"),
                weightUnit: weightUnit,
                onInsert: { sets in
                    insertWarmupSets(sets)
                    showWarmupCalculator = false
                },
                onCancel: { showWarmupCalculator = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showProgressChart) {
            NavigationStack {
                ExerciseProgressChartView(
                    exerciseName: exercise.name,
                    usesMetric: weightUnit.lowercased().contains("kg")
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showProgressChart = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showDemo) {
            ExerciseDemoSheet(exerciseName: exercise.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Bodyweight pill

    /// Header pill that surfaces the bodyweight mode for this exercise.
    /// - `forcedOn`: green "BW" badge with a lock — pull-ups, push-ups, etc.
    ///   stay bodyweight no matter what. Weight column = added/assistance.
    /// - `forcedOff`: hidden. Barbell bench can't be "added bodyweight"; no
    ///   reason to show the affordance.
    /// - `optional`: tappable toggle. Off = absolute weight, on = added on
    ///   top of body. The user's call.
    @ViewBuilder
    private var bodyweightPill: some View {
        let mode = BodyweightDetector.mode(for: exercise.name)
        switch mode {
        case .forcedOff:
            EmptyView()
        case .forcedOn:
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .heavy))
                Text("BW")
                    .font(.system(size: 11, weight: .heavy))
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.green.opacity(0.6))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.14))
            .clipShape(.capsule)
            .accessibilityLabel("Bodyweight exercise, weight column tracks added weight")
        case .optional:
            let isOn = exercise.sets.first(where: { !$0.isCompleted })?.isBodyweight
                    ?? exercise.sets.first?.isBodyweight
                    ?? false
            Button {
                toggleBodyweight(to: !isOn)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .heavy))
                    Text("BW")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundStyle(isOn ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isOn ? Color.green : Color.primary.opacity(0.08))
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isOn)
            .accessibilityLabel(isOn ? "Bodyweight mode on" : "Bodyweight mode off")
        }
    }

    /// Flip the bodyweight flag on every incomplete set. Completed sets are
    /// historical and stay untouched (their stored weight is what was
    /// logged at the time).
    ///
    /// When turning ON, zero out incomplete-set weights — the previous
    /// value was an absolute load (e.g. 135 lb bench), and reinterpreting
    /// it as "+135 lb added to bodyweight" would be wildly wrong. Let the
    /// user type the added weight fresh.
    private func toggleBodyweight(to newValue: Bool) {
        for i in exercise.sets.indices where !exercise.sets[i].isCompleted {
            exercise.sets[i].isBodyweight = newValue
            if newValue {
                exercise.sets[i].weight = 0
            }
        }
    }

    /// When the card mounts, enforce forced bodyweight modes on incomplete
    /// sets. Covers two corner cases:
    ///   1. A persisted session created before the detector knew about the
    ///      exercise name (forced state was wrong at the time it was saved).
    ///   2. A custom exercise where the user picked a name that now matches
    ///      a forced pattern after a detector update.
    /// Completed sets are skipped — their logged data is authoritative.
    private func syncBodyweightFlagToClassification() {
        let target: Bool
        switch BodyweightDetector.mode(for: exercise.name) {
        case .forcedOn: target = true
        case .forcedOff: target = false
        case .optional: return
        }
        for i in exercise.sets.indices where !exercise.sets[i].isCompleted {
            if exercise.sets[i].isBodyweight != target {
                exercise.sets[i].isBodyweight = target
            }
        }
    }

    /// Pick a working-weight baseline for the warmup calculator. Priority:
    /// first non-warmup set with a positive weight, then the muted
    /// previous-session suggestion on set 1, otherwise zero (which the
    /// sheet treats as "user must type a number").
    private func detectWorkingWeight() -> Double {
        if let working = exercise.sets.first(where: { $0.tag != .warmup && $0.weight > 0 }) {
            return abs(working.weight)
        }
        if let firstSet = exercise.sets.first, firstSet.previousWeight > 0 {
            return firstSet.previousWeight
        }
        return 0
    }

    /// Prepend the calculated warmup sets to the exercise. They go at
    /// the top because Strong/Hevy/most lifters expect warmups before
    /// working sets; existing rows are renumbered to keep the index
    /// column sequential.
    private func insertWarmupSets(_ sets: [WarmupSetDraft]) {
        let restDefault = exercise.sets.first?.restSeconds ?? defaultRest
        let isBW = exercise.sets.first?.isBodyweight ?? false
        var newSets: [SessionSet] = sets.map { draft in
            SessionSet(
                index: 0,
                previousWeight: 0,
                previousReps: 0,
                weight: draft.weight,
                reps: draft.reps,
                tag: .warmup,
                isCompleted: false,
                restSeconds: restDefault,
                isBodyweight: isBW
            )
        }
        newSets.append(contentsOf: exercise.sets)
        for i in newSets.indices {
            newSets[i].index = i + 1
        }
        exercise.sets = newSets
    }

    private var pinnedNoteBanner: some View {
        Button {
            showNoteEditor = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.yellow)
                    .padding(.top, 1)
                Text(pinnedNote)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.yellow.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    /// True when this set is the FIRST un-completed set, the prior set
    /// was crushed (matched or exceeded last-session reps at the same
    /// weight), and the last session's same-position weight is known.
    /// Used to surface the "Crushed last session, +5?" bump banner.
    private func shouldShowBumpSuggestion(for set: SessionSet) -> Bool {
        guard !set.isCompleted else { return false }
        guard let firstUncompletedIdx = exercise.sets.firstIndex(where: { !$0.isCompleted }),
              exercise.sets[firstUncompletedIdx].id == set.id else { return false }
        // Need a previously-completed set in this same exercise.
        guard let priorIdx = exercise.sets[..<firstUncompletedIdx].lastIndex(where: \.isCompleted) else {
            return false
        }
        let priorSet = exercise.sets[priorIdx]
        // Prior set's weight should match the suggestion (i.e. user is
        // continuing at the same weight).
        guard priorSet.weight > 0,
              priorSet.previousWeight > 0,
              abs(priorSet.weight - priorSet.previousWeight) < 0.01 else { return false }
        // Did they match or exceed the same-position last-session reps?
        return priorSet.reps >= priorSet.previousReps && priorSet.previousReps > 0
    }

    private func suggestedBumpWeight(for set: SessionSet) -> Double {
        // 2.5 for kg, 5 for lbs. Use the unit string passed in to decide.
        let increment: Double = weightUnit.lowercased().contains("kg") ? 2.5 : 5.0
        // Find the prior completed set's weight as the base.
        guard let priorIdx = exercise.sets.lastIndex(where: { $0.isCompleted && $0.id != set.id }) else {
            return 0
        }
        return exercise.sets[priorIdx].weight + increment
    }

    private func bumpSuggestionBanner(for set: Binding<SessionSet>) -> some View {
        let suggested = suggestedBumpWeight(for: set.wrappedValue)
        let suggestedStr = suggested == suggested.rounded()
            ? "\(Int(suggested))"
            : String(format: "%.1f", suggested)
        return Button {
            set.wrappedValue.weight = suggested
            // Clear the "previousWeight" suggestion so the new target
            // shows in primary color (it's now the user's choice).
            set.wrappedValue.previousWeight = 0
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Crushed last set. Try \(suggestedStr) \(weightUnit)?")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("Use")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.22))
                    .clipShape(.capsule)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [.purple, .indigo],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .transition(.scale.combined(with: .opacity))
    }

    private func addSet() {
        let lastSet = exercise.sets.last
        let nextIndex = (lastSet?.index ?? 0) + 1
        let new = SessionSet(
            index: nextIndex,
            previousWeight: lastSet?.previousWeight ?? 0,
            previousReps: lastSet?.previousReps ?? 0,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
            tag: .normal,
            isCompleted: false,
            restSeconds: lastSet?.restSeconds ?? defaultRest
        )
        exercise.sets.append(new)
    }

}

/// Single set row inside an exercise card. Tap-buttons (no real TextField)
/// so iOS's system keyboard never appears; the parent's StrongKeypad handles
/// input. While focused, the cell shows the parent's `editingText` buffer
/// so trailing decimals etc. are preserved.
struct SetRow: View {
    @Binding var set: SessionSet
    @Binding var focusedField: FieldFocus?
    let editingText: String
    let onTapSetNumber: () -> Void
    let onToggleComplete: () -> Void

    @State private var showRPEPicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if set.isCompleted, let rpe = set.rpe {
                rpeChip(rpe: rpe)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showRPEPicker) {
            RPEPickerSheet(
                current: set.rpe,
                onPick: { value in
                    set.rpe = value
                    showRPEPicker = false
                },
                onClear: {
                    set.rpe = nil
                    showRPEPicker = false
                }
            )
            .presentationDetents([.fraction(0.55)])
        }
    }

    private var mainRow: some View {
        HStack(spacing: 0) {
            // Tappable set number / tag badge
            Button(action: onTapSetNumber) {
                ZStack {
                    if set.tag == .normal {
                        Text("\(set.index)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                    } else {
                        Text(set.tag.badge)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(tagColor)
                            .clipShape(Circle())
                    }
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            // Previous performance
            Group {
                if set.previousWeight > 0 || set.previousReps > 0 {
                    Text(formatPrev())
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Weight cell. Tap focuses the keypad; on bodyweight sets a
            // long-press cycles "added weight → assisted → bodyweight only"
            // by flipping the sign of the entered value, no separate menu.
            cellButton(
                state: displayText(for: .weight(setId: set.id)),
                isFocused: focusedField == .weight(setId: set.id),
                width: 70
            ) {
                focusedField = .weight(setId: set.id)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        guard set.isBodyweight else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if set.weight > 0 {
                            set.weight = -set.weight        // added → assisted
                        } else if set.weight < 0 {
                            set.weight = 0                  // assisted → bodyweight only
                        } else {
                            // BW → re-enter edit so user types positive added weight
                            focusedField = .weight(setId: set.id)
                        }
                    }
            )

            // Reps cell
            cellButton(
                state: displayText(for: .reps(setId: set.id)),
                isFocused: focusedField == .reps(setId: set.id),
                width: 60
            ) {
                focusedField = .reps(setId: set.id)
            }
            .padding(.leading, 6)

            // Complete checkbox — open square when unchecked, filled green
            // checkmark when complete. Long-press to attach an RPE
            // value (5-10). Setting RPE auto-marks the set complete so
            // the gesture is a one-shot for "I finished this set at RPE 8".
            Button(action: onToggleComplete) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(set.isCompleted ? Color.green : Color.primary.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(set.isCompleted ? Color.white : Color.secondary.opacity(0.45))
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showRPEPicker = true
                    }
            )
            .padding(.leading, 6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(set.isCompleted ? Color.green.opacity(0.10) : Color.clear)
        .clipShape(.rect(cornerRadius: 10))
    }

    /// Tiny chip below the row showing the recorded RPE. Color shifts
    /// from neutral to red as the value climbs so the lifter can scan
    /// the row stack and see fatigue trending across the session.
    private func rpeChip(rpe: Double) -> some View {
        HStack(spacing: 4) {
            Spacer()
            Text("RPE \(formatRPE(rpe))")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(rpeColor(rpe))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(rpeColor(rpe).opacity(0.15))
                )
                .padding(.trailing, 42)
        }
        .padding(.bottom, 4)
    }

    private func rpeColor(_ rpe: Double) -> Color {
        switch rpe {
        case ..<7: return .green
        case 7..<8.5: return .yellow
        case 8.5..<9.5: return .orange
        default: return .red
        }
    }

    private func formatRPE(_ rpe: Double) -> String {
        rpe == rpe.rounded() ? "\(Int(rpe))" : String(format: "%.1f", rpe)
    }

    /// Pick what to render in a cell. Three states:
    ///   1. Field is focused: show the live-edit buffer
    ///   2. Actual value > 0: show the typed/logged value in primary color
    ///   3. Actual is 0 but a previous-session value exists: show that as
    ///      a MUTED suggestion (user can ✓ to accept or type to override)
    /// Bodyweight sets render "BW" when weight is 0 and prefix +/- when not,
    /// matching Strong's "Weighted Bodyweight" / "Assisted Bodyweight" types.
    private func displayText(for field: FieldFocus) -> (text: String, isSuggestion: Bool) {
        if focusedField == field {
            return (editingText, false)
        }
        switch field {
        case .weight:
            if set.weight != 0 { return (formatBodyweightSign(set.weight), false) }
            if set.isBodyweight, set.previousWeight == 0 { return ("BW", false) }
            if set.previousWeight != 0 { return (formatBodyweightSign(set.previousWeight), true) }
            if set.isBodyweight { return ("BW", false) }
            return ("", false)
        case .reps:
            if set.reps > 0 { return ("\(set.reps)", false) }
            if set.previousReps > 0 { return ("\(set.previousReps)", true) }
            return ("", false)
        }
    }

    /// Render the weight with a leading +/- when this is a bodyweight
    /// set, so "+25" reads as "+25 added" and "-30" reads as "-30 assisted."
    /// Plain weight (no bodyweight flag) renders without a sign as before.
    private func formatBodyweightSign(_ value: Double) -> String {
        if !set.isBodyweight {
            return formatWeight(abs(value))
        }
        if value > 0 {
            return "+\(formatWeight(value))"
        } else if value < 0 {
            return "-\(formatWeight(abs(value)))"
        } else {
            return "BW"
        }
    }

    private func cellButton(state: (text: String, isSuggestion: Bool), isFocused: Bool, width: CGFloat, action: @escaping () -> Void) -> some View {
        let displayValue = state.text.isEmpty ? "0" : state.text
        let foreground: Color = {
            if state.text.isEmpty { return Color.secondary.opacity(0.5) }
            if state.isSuggestion { return Color.secondary.opacity(0.7) }
            return Color.primary
        }()
        return Button(action: action) {
            Text(displayValue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: width, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isFocused ? Color.blue.opacity(0.12) : Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isFocused ? Color.blue : Color.clear, lineWidth: 1.4)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var tagColor: Color {
        switch set.tag {
        case .warmup: return .orange
        case .dropSet: return .purple
        case .failure: return .red
        case .normal: return .clear
        }
    }

    private func formatPrev() -> String {
        guard set.previousWeight != 0 || set.previousReps > 0 else { return "-" }
        let wStr: String
        if set.isBodyweight && set.previousWeight == 0 {
            wStr = "BW"
        } else if set.isBodyweight && set.previousWeight > 0 {
            wStr = "+\(formatWeight(set.previousWeight))"
        } else if set.isBodyweight && set.previousWeight < 0 {
            wStr = "-\(formatWeight(abs(set.previousWeight)))"
        } else {
            wStr = formatWeight(set.previousWeight)
        }
        return "\(wStr) × \(set.previousReps)"
    }

    private func formatWeight(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

enum FieldFocus: Hashable, Equatable {
    case weight(setId: String)
    case reps(setId: String)
}

/// Strong-style RPE picker. Long-press the ✓ on a set row to bring it
/// up. Half-step values (6.5, 7.5, etc.) supported because Mike Israetel
/// users want them. "Clear" removes the recorded value.
struct RPEPickerSheet: View {
    let current: Double?
    let onPick: (Double) -> Void
    let onClear: () -> Void

    private let values: [Double] = [
        5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Rate of Perceived Exertion")
                    .font(.headline)
                Text("How hard did that set feel?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            onPick(value)
                        } label: {
                            Text(format(value))
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(current == value ? .white : .primary)
                                .frame(width: 52, height: 52)
                                .background(
                                    Circle()
                                        .fill(current == value ? rpeColor(value) : Color.primary.opacity(0.06))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            current == value ? rpeColor(value) : rpeColor(value).opacity(0.3),
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }

            VStack(alignment: .leading, spacing: 6) {
                rpeGuideRow(value: "5-6", text: "Easy. Could do many more.")
                rpeGuideRow(value: "7", text: "Moderate. 3 reps in reserve.")
                rpeGuideRow(value: "8", text: "Hard. 2 reps in reserve.")
                rpeGuideRow(value: "9", text: "Very hard. 1 rep in reserve.")
                rpeGuideRow(value: "10", text: "Max effort. Couldn't do another rep.")
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer()

            if current != nil {
                Button(action: onClear) {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
    }

    private func format(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func rpeColor(_ rpe: Double) -> Color {
        switch rpe {
        case ..<7: return .green
        case 7..<8.5: return .yellow
        case 8.5..<9.5: return .orange
        default: return .red
        }
    }

    private func rpeGuideRow(value: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(.primary)
                .frame(width: 32, alignment: .leading)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Action sheet for assigning a Strong-style set tag.
struct SetTagPicker: View {
    let current: SetType
    let onPick: (SetType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Set Type")
                .font(.headline)
                .padding(.top, 18)
                .padding(.bottom, 8)
            ForEach([SetType.normal, .warmup, .dropSet, .failure], id: \.self) { (type: SetType) in
                Button {
                    onPick(type)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(badgeBackground(for: type))
                                .frame(width: 26, height: 26)
                            Text(type == .normal ? "1" : type.badge)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(type == .normal ? Color.primary : Color.white)
                        }
                        Text(type.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        if current == type {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
            }
            Spacer()
        }
    }

    private func badgeBackground(for type: SetType) -> Color {
        switch type {
        case .normal: return Color.primary.opacity(0.10)
        case .warmup: return .orange
        case .dropSet: return .purple
        case .failure: return .red
        }
    }
}

/// Bottom rest-timer banner with live countdown via TimelineView. The
/// previous version recomputed the countdown text only on body re-render,
/// which only happened when the timer state changed — so the displayed
/// number was effectively frozen. TimelineView forces a per-half-second
/// refresh so the user sees the seconds tick down.
struct RestTimerBanner: View {
    let endsAt: Date
    let onSkip: () -> Void
    let onAdjust: (Int) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Text("Rest")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text(remainingText(at: context.date))
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                Spacer()
                Button {
                    onAdjust(-15)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Button {
                    onAdjust(15)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Button(action: onSkip) {
                Text("Skip Rest")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color.white)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(LinearGradient(colors: [.blue, .blue.opacity(0.85)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing))
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }

    private func remainingText(at now: Date) -> String {
        let secs = max(0, Int(endsAt.timeIntervalSince(now).rounded()))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Sheet for editing the pinned exercise note. Yellow accent matches
/// the inline banner so the user immediately understands what surface
/// they're editing.
struct PinnedNoteEditorSheet: View {
    let exerciseName: String
    let initialText: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.yellow)
                    Text("Pinned note shows on every \(exerciseName) session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                TextEditor(text: $text)
                    .focused($focused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.yellow.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.yellow.opacity(0.30), lineWidth: 0.6)
                    )
                    .frame(minHeight: 140)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Pinned Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(text) }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                text = initialText
                focused = true
            }
        }
    }
}
