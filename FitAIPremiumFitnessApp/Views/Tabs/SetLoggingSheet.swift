import SwiftUI

struct SetLoggingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let onComplete: ([SetLog], Bool) -> Void

    @State private var sets: [SetLog]
    @State private var restTimerActive: Bool = false
    @State private var restSecondsRemaining: Int = 90
    @State private var restTimerTotal: Int = 90
    @State private var timer: Timer? = nil
    @State private var currentSetIndex: Int = 0
    @State private var showPRCelebration: Bool = false
    @State private var newPR: Bool = false
    @State private var completedSetTrigger: Int = 0

    private let exerciseLogService = ExerciseLogService.shared

    private var history: ExerciseHistory {
        exerciseLogService.history(for: exercise.name)
    }

    private var allSetsCompleted: Bool {
        sets.allSatisfy(\.isCompleted)
    }

    private var completedSetsCount: Int {
        sets.filter(\.isCompleted).count
    }

    init(exercise: Exercise, onComplete: @escaping ([SetLog], Bool) -> Void) {
        self.exercise = exercise
        self.onComplete = onComplete

        let lastSession = ExerciseLogService.shared.lastSession(for: exercise.name)
        var initialSets: [SetLog] = []
        for i in 0..<exercise.sets {
            let prevWeight = lastSession?.sets[safe: i]?.weight ?? 0
            let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
            initialSets.append(SetLog(weight: prevWeight, reps: prevReps))
        }
        _sets = State(initialValue: initialSets)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    exerciseHeader

                    if let last = history.lastSession {
                        previousSessionCard(last)
                    }

                    if restTimerActive {
                        restTimerCard
                    }

                    setsListSection

                    addDropSetButton

                    if allSetsCompleted {
                        completeButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if completedSetsCount > 0 {
                        Button("Save") { saveAndDismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .overlay {
                if showPRCelebration {
                    prCelebrationOverlay
                }
            }
        }
        .onDisappear { timer?.invalidate() }
        .sensoryFeedback(.success, trigger: showPRCelebration)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: muscleIcon(exercise.muscleGroup))
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.title3.weight(.bold))
                    HStack(spacing: 8) {
                        Text(exercise.muscleGroup)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.quaternary)
                        Text("\(exercise.sets) sets × \(exercise.reps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 0) {
                statPill(
                    value: history.personalBestWeight > 0 ? "\(Int(history.personalBestWeight))kg" : "—",
                    label: "Best Weight",
                    color: .orange
                )
                pillDivider
                statPill(
                    value: history.personalBestReps > 0 ? "\(history.personalBestReps)" : "—",
                    label: "Best Reps",
                    color: .green
                )
                pillDivider
                statPill(
                    value: history.logs.count > 0 ? "\(history.logs.count)" : "—",
                    label: "Sessions",
                    color: .cyan
                )
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    // MARK: - Previous Session

    private func previousSessionCard(_ session: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Last Session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(session.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                ForEach(Array(session.sets.prefix(6).enumerated()), id: \.offset) { idx, set in
                    VStack(spacing: 2) {
                        Text("S\(idx + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(set.weight))")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                        Text("×\(set.reps)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.04), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.blue.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Rest Timer

    private var restTimerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("Rest Timer")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatRestTime(restSecondsRemaining))
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(restSecondsRemaining <= 10 ? .red : .primary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: restSecondsRemaining <= 10 ? [.red, .orange] : [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * (Double(restSecondsRemaining) / Double(restTimerTotal)), 0), height: 6)
                        .animation(.linear(duration: 1), value: restSecondsRemaining)
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Text("Rest 90s for optimal hypertrophy")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    restSecondsRemaining = min(restSecondsRemaining + 30, 300)
                } label: {
                    Text("+30s")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(.capsule)
                }

                Button {
                    stopRestTimer()
                } label: {
                    Text("Skip")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(.capsule)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.12), lineWidth: 1)
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
    }

    // MARK: - Sets List

    private var setsListSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Sets")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(completedSetsCount)/\(sets.count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(.capsule)
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                setRow(index: index, set: set)
            }
        }
    }

    private func setRow(index: Int, set: SetLog) -> some View {
        let isActive = index == currentSetIndex && !set.isCompleted
        let bgColor: Color = set.isCompleted ? Color.green.opacity(0.04) : (isActive ? Color.blue.opacity(0.04) : Color.primary.opacity(0.03))

        return HStack(spacing: 14) {
            setIndexLabel(index: index, set: set, isActive: isActive)
            setInputFields(index: index, isDisabled: set.isCompleted)
            Spacer()
            setActions(index: index, set: set)
        }
        .padding(14)
        .background(bgColor)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            isActive && !set.isCompleted ?
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.blue.opacity(0.15), lineWidth: 1) : nil
        )
        .opacity(set.isCompleted ? 0.7 : 1)
        .sensoryFeedback(.impact(weight: .medium), trigger: completedSetTrigger)
    }

    private func setIndexLabel(index: Int, set: SetLog, isActive: Bool) -> some View {
        VStack(spacing: 2) {
            if set.isDropSet {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
            } else {
                let labelColor: Color = set.isCompleted ? .green : (isActive ? .primary : .secondary)
                Text("\(index + 1)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(labelColor)
            }
            if set.isFailure {
                Text("F")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 28)
    }

    private func setInputFields(index: Int, isDisabled: Bool) -> some View {
        let fieldBg = Color.primary.opacity(isDisabled ? 0.02 : 0.06)
        return HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("WEIGHT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                TextField("0", value: Binding(
                    get: { sets[index].weight },
                    set: { sets[index].weight = $0 }
                ), format: .number)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .disabled(isDisabled)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(fieldBg)
            .clipShape(.rect(cornerRadius: 10))

            Text("×")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 2) {
                Text("REPS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                TextField("0", value: Binding(
                    get: { sets[index].reps },
                    set: { sets[index].reps = $0 }
                ), format: .number)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(width: 60)
                .disabled(isDisabled)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(fieldBg)
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func setActions(index: Int, set: SetLog) -> some View {
        if !set.isCompleted {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        sets[index].isFailure.toggle()
                    }
                } label: {
                    let iconName = set.isFailure ? "exclamationmark.circle.fill" : "exclamationmark.circle"
                    let iconColor: Color = set.isFailure ? .red : Color(.tertiaryLabel)
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(iconColor)
                }

                Button {
                    completeSet(at: index)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                }
            }
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
        }
    }

    // MARK: - Actions

    private var addDropSetButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                let lastWeight = sets.last?.weight ?? 0
                sets.append(SetLog(weight: lastWeight * 0.7, reps: 0, isDropSet: true))
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Drop Set")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.purple)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.purple.opacity(0.08))
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var completeButton: some View {
        Button {
            saveAndDismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("Exercise Complete")
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .clipShape(.rect(cornerRadius: 16))
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - PR Celebration

    private var prCelebrationOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: showPRCelebration)

            Text("NEW PR!")
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(.yellow)

            Text("You just set a personal record!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 24))
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(duration: 0.4)) {
                    showPRCelebration = false
                }
            }
        }
    }

    // MARK: - Logic

    private func completeSet(at index: Int) {
        withAnimation(.spring(duration: 0.35)) {
            sets[index].isCompleted = true
            sets[index].timestamp = Date()
            completedSetTrigger += 1

            let weight = sets[index].weight
            let bestWeight = history.personalBestWeight
            if weight > bestWeight && bestWeight > 0 {
                newPR = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
                        showPRCelebration = true
                    }
                }
            }

            if index < sets.count - 1 {
                currentSetIndex = index + 1
                startRestTimer()
            }
        }
    }

    private func startRestTimer() {
        timer?.invalidate()
        let totalSets = exercise.sets
        restTimerTotal = totalSets >= 4 ? 120 : 90
        restSecondsRemaining = restTimerTotal
        withAnimation(.spring(duration: 0.4)) {
            restTimerActive = true
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if restSecondsRemaining > 0 {
                    restSecondsRemaining -= 1
                } else {
                    stopRestTimer()
                }
            }
        }
    }

    private func stopRestTimer() {
        timer?.invalidate()
        withAnimation(.spring(duration: 0.3)) {
            restTimerActive = false
        }
    }

    private func saveAndDismiss() {
        let completedSets = sets.filter(\.isCompleted)
        onComplete(completedSets, newPR)
        dismiss()
    }

    private func formatRestTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func muscleIcon(_ group: String) -> String {
        let lower = group.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("shoulder") || lower.contains("delt") { return "figure.boxing" }
        if lower.contains("back") || lower.contains("lat") { return "figure.rowing" }
        if lower.contains("bicep") || lower.contains("tricep") || lower.contains("arm") { return "figure.arms.open" }
        if lower.contains("quad") || lower.contains("leg") || lower.contains("ham") || lower.contains("calf") { return "figure.run" }
        if lower.contains("glute") { return "figure.stairs" }
        if lower.contains("core") || lower.contains("ab") || lower.contains("oblique") { return "figure.core.training" }
        return "dumbbell.fill"
    }
}
