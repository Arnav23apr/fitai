import SwiftUI

struct SetLoggingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
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
    @State private var useBodyweight: Bool = false
    @State private var usedAISuggestions: Bool = false
    @State private var weightStrings: [String] = []

    private let exerciseLogService = ExerciseLogService.shared

    private var isBodyweightEligible: Bool {
        BodyweightDetector.isBodyweightExercise(exercise.name)
    }

    private var isEquipmentOnly: Bool {
        BodyweightDetector.isEquipmentOnly(exercise.name)
    }

    private var history: ExerciseHistory {
        exerciseLogService.history(for: exercise.name)
    }

    private var weightUnit: String {
        appState.profile.usesMetric ? "kg" : "lbs"
    }

    private var bodyweightValue: Double {
        let kg = appState.profile.weightKg
        return appState.profile.usesMetric ? kg : kg * 2.205
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
        let wasBW = lastSession?.sets.first?.isBodyweight ?? false
        let hasLastSession = lastSession != nil

        let hasAISuggestions = !exercise.suggestedWeights.isEmpty && !exercise.suggestedReps.isEmpty

        for i in 0..<exercise.sets {
            if hasLastSession {
                let prevWeight = lastSession?.sets[safe: i]?.weight ?? 0
                let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
                initialSets.append(SetLog(weight: prevWeight, reps: prevReps, isBodyweight: wasBW))
            } else if hasAISuggestions {
                let sugWeight = exercise.suggestedWeights[safe: i] ?? 0
                let sugReps = exercise.suggestedReps[safe: i] ?? 0
                initialSets.append(SetLog(weight: sugWeight, reps: sugReps, isBodyweight: false))
            } else {
                let (defWeight, defReps) = Self.experienceDefaults()
                initialSets.append(SetLog(weight: defWeight, reps: defReps, isBodyweight: false))
            }
        }
        _sets = State(initialValue: initialSets)
        _useBodyweight = State(initialValue: wasBW)
        _usedAISuggestions = State(initialValue: !hasLastSession && hasAISuggestions)
        _weightStrings = State(initialValue: initialSets.map { Self.formatWeight($0.weight) })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    exerciseHeader

                    if usedAISuggestions {
                        aiSuggestedBanner
                    }

                    if isBodyweightEligible || isEquipmentOnly {
                        bodyweightToggleCard
                    }

                    if !useBodyweight && isBodyweightEligible && !isEquipmentOnly {
                        totalLoadInfo
                    }

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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
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

    // MARK: - AI Suggested Banner

    private var aiSuggestedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(.cyan)
            Text("AI Suggested weights & reps based on your profile")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    usedAISuggestions = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color.cyan.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.cyan.opacity(0.1), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Bodyweight Toggle

    private var bodyweightToggleCard: some View {
        Group {
            if isEquipmentOnly && !isBodyweightEligible {
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bodyweight")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        Text("Requires equipment")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }

                    Spacer()

                    ZStack {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 48, height: 28)
                        Circle()
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 22, height: 22)
                            .offset(x: -10)
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.02))
                .clipShape(.rect(cornerRadius: 14))
                .opacity(0.6)
            } else {
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        useBodyweight.toggle()
                        if useBodyweight {
                            let bw = bodyweightValue
                            for i in sets.indices {
                                if !sets[i].isCompleted {
                                    sets[i].weight = bw
                                    sets[i].isBodyweight = true
                                    if i < weightStrings.count {
                                        weightStrings[i] = Self.formatWeight(bw)
                                    }
                                }
                            }
                        } else {
                            let lastSession = exerciseLogService.lastSession(for: exercise.name)
                            for i in sets.indices {
                                if !sets[i].isCompleted {
                                    sets[i].isBodyweight = false
                                    let newWeight: Double
                                    if let prev = lastSession?.sets[safe: i]?.weight {
                                        newWeight = prev
                                    } else if let suggested = exercise.suggestedWeights[safe: i] {
                                        newWeight = suggested
                                    } else {
                                        newWeight = 0
                                    }
                                    sets[i].weight = newWeight
                                    if i < weightStrings.count {
                                        weightStrings[i] = Self.formatWeight(newWeight)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(useBodyweight ? .white : .green)
                            .frame(width: 32, height: 32)
                            .background(useBodyweight ? Color.green : Color.green.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bodyweight")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(useBodyweight ? "Using your body weight (\(Int(bodyweightValue)) \(weightUnit))" : "Tap to use bodyweight")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ZStack {
                            Capsule()
                                .fill(useBodyweight ? Color.green : Color.primary.opacity(0.1))
                                .frame(width: 48, height: 28)
                            Circle()
                                .fill(.white)
                                .frame(width: 22, height: 22)
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                                .offset(x: useBodyweight ? 10 : -10)
                        }
                    }
                    .padding(14)
                    .background(
                        useBodyweight ?
                        Color.green.opacity(0.06) : Color.primary.opacity(0.03)
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        useBodyweight ?
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.green.opacity(0.15), lineWidth: 1) : nil
                    )
                }
                .sensoryFeedback(.impact(weight: .light), trigger: useBodyweight)
            }
        }
    }

    // MARK: - Total Load Info

    @ViewBuilder
    private var totalLoadInfo: some View {
        let addedWeight = sets.first(where: { !$0.isCompleted })?.weight ?? sets.first?.weight ?? 0
        if addedWeight > 0 {
            let totalLoad = bodyweightValue + addedWeight
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                Text("Total load: \(Int(totalLoad))\(weightUnit) (\(Int(bodyweightValue)) BW + \(Int(addedWeight)) added)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(10)
            .background(Color.blue.opacity(0.05))
            .clipShape(.rect(cornerRadius: 10))
        }
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
                    value: history.personalBestWeight > 0 ? "\(Int(history.personalBestWeight))\(weightUnit)" : "-",
                    label: "Best Weight",
                    color: .orange
                )
                pillDivider
                statPill(
                    value: history.personalBestReps > 0 ? "\(history.personalBestReps)" : "-",
                    label: "Best Reps",
                    color: .green
                )
                pillDivider
                statPill(
                    value: history.logs.count > 0 ? "\(history.logs.count)" : "-",
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
                        if set.isBodyweight {
                            Text("BW")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(Int(set.weight))")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                        }
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

    private static let repsValues: [Int] = Array(0...100)

    private static func experienceDefaults() -> (weight: Double, reps: Int) {
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return (0, 10) }
        let metric = profile.usesMetric
        switch profile.trainingExperience.lowercased() {
        case "beginner":   return (metric ? 5.0  : 10.0, 12)
        case "intermediate": return (metric ? 12.5 : 27.5, 10)
        case "advanced":   return (metric ? 22.5 : 50.0, 8)
        default:           return (0, 10)
        }
    }

    private static func formatWeight(_ weight: Double) -> String {
        guard weight > 0 else { return "" }
        return weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
    }

    private func setInputFields(index: Int, isDisabled: Bool) -> some View {
        HStack(spacing: 4) {
            if useBodyweight {
                bodyweightWeightLabel
            } else {
                VStack(spacing: 4) {
                    Text(weightUnit.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)

                    let weightBinding = Binding<String>(
                        get: { index < weightStrings.count ? weightStrings[index] : "" },
                        set: { val in
                            guard index < weightStrings.count else { return }
                            let filtered = val.filter { $0.isNumber || $0 == "." }
                            weightStrings[index] = filtered
                            if let parsed = Double(filtered) {
                                sets[index].weight = parsed
                            } else if filtered.isEmpty {
                                sets[index].weight = 0
                            }
                        }
                    )

                    TextField("0", text: weightBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .frame(width: 76, height: 68)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .disabled(isDisabled)
                }
            }

            Text("×")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 0) {
                Text("REPS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                Picker("", selection: Binding(
                    get: { sets[index].reps },
                    set: { sets[index].reps = $0 }
                )) {
                    ForEach(Self.repsValues, id: \.self) { r in
                        Text("\(r)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .tag(r)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 80)
                .clipped()
                .disabled(isDisabled)
            }
        }
    }

    private var bodyweightWeightLabel: some View {
        VStack(spacing: 4) {
            Text("BW")
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(.green)
            Text("\(Int(bodyweightValue))")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(weightUnit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 70, height: 80)
        .background(Color.green.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
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
                let lastWeight = useBodyweight ? bodyweightValue : (sets.last?.weight ?? 0) * 0.7
                sets.append(SetLog(weight: lastWeight, reps: 0, isDropSet: true, isBodyweight: useBodyweight))
                weightStrings.append(Self.formatWeight(lastWeight))
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
            if useBodyweight {
                sets[index].weight = bodyweightValue
                sets[index].isBodyweight = true
            }
            sets[index].isCompleted = true
            sets[index].timestamp = Date()
            completedSetTrigger += 1

            let weight = sets[index].weight
            let bestWeight = history.personalBestWeight
            if weight > bestWeight && bestWeight > 0 && !useBodyweight {
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
        WorkoutSessionManager.shared.updateRestTimer(isResting: true, secondsRemaining: restSecondsRemaining)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if restSecondsRemaining > 0 {
                    restSecondsRemaining -= 1
                    WorkoutSessionManager.shared.updateRestTimer(isResting: true, secondsRemaining: restSecondsRemaining)
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
        WorkoutSessionManager.shared.updateRestTimer(isResting: false, secondsRemaining: 0)
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
