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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(exercise.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(2)
                Spacer()
                Menu {
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
                    if !isLastSet(set) {
                        Text(formatRest(set.restSeconds ?? defaultRest))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(set.isCompleted ? .green : .blue)
                            .padding(.vertical, 4)
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Text("+ Add Set (\(formatRest(defaultRest)))")
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
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func isLastSet(_ set: SessionSet) -> Bool {
        exercise.sets.last?.id == set.id
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

    private func formatRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m):00" : String(format: "%d:%02d", m, s)
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

    var body: some View {
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

            // Weight cell
            cellButton(
                state: displayText(for: .weight(setId: set.id)),
                isFocused: focusedField == .weight(setId: set.id),
                width: 70
            ) {
                focusedField = .weight(setId: set.id)
            }

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
            // checkmark when complete. Distinct icon so the unchecked state
            // doesn't look like a faded version of "complete".
            Button(action: onToggleComplete) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(set.isCompleted ? Color.green : Color.primary.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Image(systemName: set.isCompleted ? "checkmark" : "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(set.isCompleted ? Color.white : Color.secondary.opacity(0.45))
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(set.isCompleted ? Color.green.opacity(0.10) : Color.clear)
        .clipShape(.rect(cornerRadius: 10))
    }

    /// Pick what to render in a cell. Three states:
    ///   1. Field is focused: show the live-edit buffer
    ///   2. Actual value > 0: show the typed/logged value in primary color
    ///   3. Actual is 0 but a previous-session value exists: show that as
    ///      a MUTED suggestion (user can ✓ to accept or type to override)
    private func displayText(for field: FieldFocus) -> (text: String, isSuggestion: Bool) {
        if focusedField == field {
            return (editingText, false)
        }
        switch field {
        case .weight:
            if set.weight > 0 { return (formatWeight(set.weight), false) }
            if set.previousWeight > 0 { return (formatWeight(set.previousWeight), true) }
            return ("", false)
        case .reps:
            if set.reps > 0 { return ("\(set.reps)", false) }
            if set.previousReps > 0 { return ("\(set.previousReps)", true) }
            return ("", false)
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
        guard set.previousWeight > 0 || set.previousReps > 0 else { return "-" }
        let w = set.previousWeight
        let wStr: String = w == w.rounded() ? "\(Int(w))" : String(format: "%.1f", w)
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
