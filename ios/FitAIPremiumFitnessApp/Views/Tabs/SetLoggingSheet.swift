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
    @State private var plateCalcSetIndex: Int? = nil
    @State private var showWeightLimitAlert: Bool = false

    private let exerciseLogService = ExerciseLogService.shared
    private let maxWeight: Double = 9999

    private var lang: String { appState.profile.selectedLanguage }

    private var trackingMode: ExerciseTrackingMode {
        exercise.trackingMode
    }

    private var isWeighted: Bool { trackingMode == .weighted || trackingMode == .bodyweight }
    private var isTimed: Bool { trackingMode == .timed }
    private var isRepsOnly: Bool { trackingMode == .repsOnly }

    /// Bodyweight classification for `exercise.name`. Drives every gate
    /// in this sheet — toggle visibility, lock state, init defaults —
    /// so we look it up once and switch on the enum everywhere else.
    private var bwMode: BodyweightDetector.BodyweightMode {
        BodyweightDetector.mode(for: exercise.name)
    }

    /// The BW toggle card is shown on every weighted/bodyweight exercise.
    /// For `forcedOn` it locks ON (push-ups, pull-ups — bodyweight by
    /// definition, the "weight" field is added load). For `forcedOff` it
    /// locks OFF and greys out (barbell bench, lat pulldown — bodyweight
    /// makes no sense). For `optional` it's a normal toggle.
    private var showBodyweightCard: Bool { isWeighted }

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

        // Resolve the bodyweight classification once. For forced
        // exercises (push-ups, pull-ups, dips, etc.) this overrides
        // last-session state — if the prior session was logged before
        // the detector knew about the name, we still start with the
        // toggle in the right position.
        let detectorMode = BodyweightDetector.mode(for: exercise.name)
        let initialUseBW: Bool
        switch detectorMode {
        case .forcedOn:  initialUseBW = true
        case .forcedOff: initialUseBW = false
        case .optional:  initialUseBW = wasBW
        }

        let mode = exercise.trackingMode
        for i in 0..<exercise.sets {
            switch mode {
            case .timed:
                // Prefill from last session, else from the planned target.
                let prevSeconds = lastSession?.sets[safe: i]?.reps ?? 0
                let target = exercise.targetDurationSeconds
                let seconds = prevSeconds > 0 ? prevSeconds : target
                initialSets.append(SetLog(weight: 0, reps: seconds, isBodyweight: false))
            case .repsOnly:
                let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
                let suggested = exercise.suggestedReps[safe: i] ?? Int(exercise.reps) ?? 10
                initialSets.append(SetLog(weight: 0, reps: prevReps > 0 ? prevReps : suggested, isBodyweight: false))
            case .weighted, .bodyweight:
                if initialUseBW {
                    // Bodyweight mode (forced-on or carried over from
                    // last session). `weight` represents added load on
                    // top of bodyweight: 0 means pure BW, +20 means
                    // weighted, -10 means assisted. Carry the previous
                    // session's added weight forward when we have it.
                    let prevAdded = lastSession?.sets[safe: i]?.weight ?? 0
                    let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
                    let reps = prevReps > 0 ? prevReps : (Int(exercise.reps) ?? 10)
                    initialSets.append(SetLog(weight: wasBW ? prevAdded : 0, reps: reps, isBodyweight: true))
                } else if hasLastSession {
                    let prevWeight = lastSession?.sets[safe: i]?.weight ?? 0
                    let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
                    initialSets.append(SetLog(weight: prevWeight, reps: prevReps, isBodyweight: false))
                } else if hasAISuggestions {
                    let sugWeight = exercise.suggestedWeights[safe: i] ?? 0
                    let sugReps = exercise.suggestedReps[safe: i] ?? 0
                    initialSets.append(SetLog(weight: sugWeight, reps: sugReps, isBodyweight: false))
                } else {
                    let (defWeight, defReps) = Self.experienceDefaults()
                    initialSets.append(SetLog(weight: defWeight, reps: defReps, isBodyweight: false))
                }
            case .distance:
                // Cardio distance + duration. Pre-fill from last session
                // when available, otherwise leave empty for the user to
                // type during the session. The legacy SetLoggingSheet
                // doesn't have a dedicated cardio UI yet, so this just
                // produces an editable empty row that the user fills in.
                let prevDist = lastSession?.sets[safe: i]?.distanceMeters ?? 0
                let prevDur = lastSession?.sets[safe: i]?.durationSeconds ?? 0
                initialSets.append(SetLog(
                    weight: 0,
                    reps: 0,
                    isBodyweight: false,
                    distanceMeters: prevDist > 0 ? prevDist : nil,
                    durationSeconds: prevDur > 0 ? prevDur : nil
                ))
            }
        }
        _sets = State(initialValue: initialSets)
        _useBodyweight = State(initialValue: initialUseBW)
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

                    if showBodyweightCard {
                        bodyweightToggleCard
                    }

                    // Total-load hint surfaces whenever BW mode is on —
                    // it spells out "BW (80) + added (20) = 100 kg" so
                    // the user knows the typed number is added load,
                    // not absolute.
                    if useBodyweight {
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
                    Button(L.t("done", lang)) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if completedSetsCount > 0 {
                        Button(L.t("save", lang)) { saveAndDismiss() }
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
        .alert(L.t("slowDownTitle", lang), isPresented: $showWeightLimitAlert) {
            Button(L.t("ok", lang), role: .cancel) { }
        } message: {
            Text(String(format: L.t("maxWeightMsg", lang),
                        "\(Int(maxWeight))" as NSString,
                        weightUnit as NSString))
        }
    }

    // MARK: - AI Suggested Banner

    private var aiSuggestedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(.cyan)
            Text(L.t("aiSuggestedBanner", lang))
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
        switch bwMode {
        case .forcedOff:
            // Equipment-only exercise (barbell bench, lat pulldown, etc.)
            // — bodyweight isn't a meaningful concept here. Show the
            // card greyed out with a "Requires equipment" subtitle so the
            // user understands why the toggle won't move.
            return AnyView(lockedBodyweightCard(isOn: false))
        case .forcedOn:
            // Push-ups, pull-ups, dips, planks — bodyweight by
            // definition. Toggle is locked ON with a lock glyph; the
            // weight field below tracks added load over bodyweight.
            return AnyView(lockedBodyweightCard(isOn: true))
        case .optional:
            return AnyView(interactiveBodyweightCard)
        }
    }

    /// Read-only variant of the BW toggle for forced exercises. Same
    /// visual rhythm as the interactive version so the user perceives
    /// it as the same control, just immobile.
    private func lockedBodyweightCard(isOn: Bool) -> some View {
        let iconName = isOn ? "figure.walk" : "dumbbell.fill"
        let iconTint: Color = isOn ? .green : Color(.tertiaryLabel)
        let iconBg: Color = isOn ? Color.green.opacity(0.12) : Color.primary.opacity(0.06)
        let titleColor: Color = isOn ? .primary : Color(.tertiaryLabel)
        let subtitle: String = isOn
            ? "Bodyweight exercise — enter any added weight below"
            : L.t("requiresEquipment", lang)
        let cardBg: Color = isOn ? Color.green.opacity(0.06) : Color.primary.opacity(0.02)

        return HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 32, height: 32)
                .background(iconBg)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(L.t("bodyweightLabel", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(isOn ? Color.green.opacity(0.55) : Color(.tertiaryLabel))
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Capsule()
                    .fill(isOn ? Color.green : Color.primary.opacity(0.08))
                    .frame(width: 48, height: 28)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                    .offset(x: isOn ? 10 : -10)
            }
            .opacity(0.7)
        }
        .padding(14)
        .background(cardBg)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            isOn ? RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 1) : nil
        )
        .opacity(isOn ? 1.0 : 0.65)
        .accessibilityLabel(isOn ? "Bodyweight required for this exercise" : "Bodyweight not applicable")
    }

    /// Tappable BW toggle for ambiguous exercises (Bulgarian split
    /// squats, walking lunges with optional dumbbells, etc.). Flipping
    /// the toggle rewrites every incomplete set's weight to the new
    /// semantics — ON resets to 0 added, OFF restores prior/suggested
    /// absolute loads — so the input field always shows a number in
    /// the right basis without the user having to retype.
    private var interactiveBodyweightCard: some View {
        Button {
            withAnimation(.spring(duration: 0.35)) {
                useBodyweight.toggle()
                if useBodyweight {
                    // Turning ON: reinterpret incomplete-set weights as
                    // ADDED load. The prior value (e.g. 80 kg absolute)
                    // would be wildly wrong as "added", so zero it out
                    // and let the user enter +X for weighted variations.
                    for i in sets.indices where !sets[i].isCompleted {
                        sets[i].isBodyweight = true
                        sets[i].weight = 0
                        if i < weightStrings.count {
                            weightStrings[i] = ""
                        }
                    }
                } else {
                    // Turning OFF: restore prior-session/suggested
                    // absolute loads so the user has something to edit.
                    let lastSession = exerciseLogService.lastSession(for: exercise.name)
                    for i in sets.indices where !sets[i].isCompleted {
                        sets[i].isBodyweight = false
                        let newWeight: Double
                        if let prev = lastSession?.sets[safe: i]?.weight, prev > 0 {
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
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(useBodyweight ? .white : .green)
                    .frame(width: 32, height: 32)
                    .background(useBodyweight ? Color.green : Color.green.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("bodyweightLabel", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(useBodyweight
                         ? "BW \(Int(bodyweightValue)) \(weightUnit) — type added weight below"
                         : L.t("tapBodyweight", lang))
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

    // MARK: - Total Load Info

    @ViewBuilder
    private var totalLoadInfo: some View {
        // First incomplete set is the user's "current intent" — that's
        // the value we surface in the hint. Falls back to set 1 once
        // every set is logged.
        let added = sets.first(where: { !$0.isCompleted })?.weight ?? sets.first?.weight ?? 0
        let total = bodyweightValue + added
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            Group {
                if added == 0 {
                    Text("Total load: \(Int(total)) \(weightUnit) (bodyweight only)")
                } else if added > 0 {
                    Text("Total load: \(Int(total)) \(weightUnit) (\(Int(bodyweightValue)) BW + \(Int(added)) added)")
                } else {
                    Text("Net load: \(Int(total)) \(weightUnit) (\(Int(bodyweightValue)) BW − \(Int(-added)) assisted)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(Color.blue.opacity(0.05))
        .clipShape(.rect(cornerRadius: 10))
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
                    label: L.t("bestWeightLabel", lang),
                    color: .orange
                )
                pillDivider
                statPill(
                    value: history.personalBestReps > 0 ? "\(history.personalBestReps)" : "-",
                    label: L.t("bestRepsLabel", lang),
                    color: .green
                )
                pillDivider
                statPill(
                    value: history.logs.count > 0 ? "\(history.logs.count)" : "-",
                    label: L.t("sessionsLabel", lang),
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
                Text(L.t("lastSessionLabel", lang))
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
                        switch trackingMode {
                        case .timed:
                            Text(formatDuration(set.reps))
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                        case .repsOnly:
                            Text("\(set.reps)")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("reps")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        case .weighted, .bodyweight:
                            if set.isBodyweight {
                                // Render the prior session's added-load
                                // sign so the user sees the actual
                                // resistance: "BW" for pure bodyweight,
                                // "+25" for weighted, "−10" for assisted.
                                Text(bodyweightSetLabel(weight: set.weight))
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.green)
                            } else {
                                Text("\(Int(set.weight))")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                            }
                            Text("×\(set.reps)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        case .distance:
                            Text(set.durationSeconds.map { formatDuration($0) } ?? "-")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("dist")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
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
                Text(L.t("restTimer", lang))
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
                        // Clamp the ratio at 1.0 so the bar never extends
                        // beyond its container if remaining ever exceeds total
                        // (e.g. user taps +30s near a fresh start).
                        .frame(width: max(geo.size.width * min(Double(restSecondsRemaining) / Double(max(restTimerTotal, 1)), 1.0), 0), height: 6)
                        .animation(.linear(duration: 1), value: restSecondsRemaining)
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Text(L.t("restMessage", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    restSecondsRemaining = min(restSecondsRemaining + 30, 300)
                    // Keep the bar's denominator >= remaining so the
                    // progress ratio stays in [0, 1] and the bar grows
                    // visibly when the user extends rest.
                    restTimerTotal = max(restTimerTotal, restSecondsRemaining)
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
                    Text(L.t("skip", lang))
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
                Text(L.t("setsTitle", lang))
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

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 && s == 0 { return "\(m)m" }
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return "\(s)s"
    }

    /// Compact label for a stored bodyweight set's added load.
    /// "BW" for 0, "+25" for weighted, "−10" for assisted. Used by the
    /// previous-session card so the history is legible at a glance.
    private func bodyweightSetLabel(weight: Double) -> String {
        if weight == 0 { return "BW" }
        let abs = abs(weight)
        let body: String = abs.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(abs))"
            : String(format: "%.1f", abs)
        return weight > 0 ? "+\(body)" : "−\(body)"
    }

    private static func formatWeight(_ weight: Double) -> String {
        guard weight > 0 else { return "" }
        return weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
    }

    @ViewBuilder
    private func setInputFields(index: Int, isDisabled: Bool) -> some View {
        switch trackingMode {
        case .timed:
            timedInputField(index: index, isDisabled: isDisabled)
        case .repsOnly:
            repsOnlyInputField(index: index, isDisabled: isDisabled)
        case .weighted, .bodyweight:
            weightedInputFields(index: index, isDisabled: isDisabled)
        case .distance:
            // Cardio distance + duration. Legacy SetLoggingSheet falls
            // back to the timed input for now; the active session UI
            // (ActiveSessionView + ExerciseCard) is the canonical
            // logging surface for cardio.
            timedInputField(index: index, isDisabled: isDisabled)
        }
    }

    private func timedInputField(index: Int, isDisabled: Bool) -> some View {
        let totalSeconds = sets[safe: index]?.reps ?? 0
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("MIN")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                Picker("", selection: Binding(
                    get: { minutes },
                    set: { newM in
                        guard sets.indices.contains(index) else { return }
                        let s = sets[index].reps % 60
                        sets[index].reps = newM * 60 + s
                    }
                )) {
                    ForEach(0...60, id: \.self) { m in
                        Text("\(m)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 80)
                .clipped()
                .disabled(isDisabled)
            }

            Text(":")
                .font(.title3.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("SEC")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                Picker("", selection: Binding(
                    get: { seconds },
                    set: { newS in
                        guard sets.indices.contains(index) else { return }
                        let m = sets[index].reps / 60
                        sets[index].reps = m * 60 + newS
                    }
                )) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { s in
                        Text(String(format: "%02d", s))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 80)
                .clipped()
                .disabled(isDisabled)
            }
        }
    }

    private func repsOnlyInputField(index: Int, isDisabled: Bool) -> some View {
        VStack(spacing: 4) {
            Text(L.t("repsUpper", lang))
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
            .frame(width: 80, height: 80)
            .clipped()
            .disabled(isDisabled)
        }
    }

    private func weightedInputFields(index: Int, isDisabled: Bool) -> some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                // Label adapts to the active mode. In BW mode the field
                // holds *added* weight (0 = pure BW, +X = weighted),
                // which is a different concept than absolute load, so
                // we relabel the column to "+ KG" to signal that.
                Text(useBodyweight ? "+ \(weightUnit.uppercased())" : weightUnit.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(useBodyweight ? Color.green : Color(.tertiaryLabel))

                let weightBinding = Binding<String>(
                    get: { index < weightStrings.count ? weightStrings[index] : "" },
                    set: { val in
                        guard index < weightStrings.count else { return }
                        let filtered = val.filter { $0.isNumber || $0 == "." }
                        if let parsed = Double(filtered), parsed > maxWeight {
                            showWeightLimitAlert = true
                            return
                        }
                        weightStrings[index] = filtered
                        if let parsed = Double(filtered) {
                            sets[index].weight = parsed
                        } else if filtered.isEmpty {
                            sets[index].weight = 0
                        }
                    }
                )

                ZStack(alignment: .topTrailing) {
                    TextField(useBodyweight ? "0" : "0", text: weightBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .frame(width: 76, height: 68)
                        .background(useBodyweight ? Color.green.opacity(0.08) : Color.primary.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(useBodyweight ? Color.green.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .disabled(isDisabled)

                    if !useBodyweight, PlateCalculator.isBarbellExercise(exercise.name), sets[index].weight > 0 {
                            Button {
                                plateCalcSetIndex = index
                            } label: {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color(.systemBackground), lineWidth: 1.5)
                                    )
                            }
                            .offset(x: 6, y: -6)
                            .popover(isPresented: Binding(
                                get: { plateCalcSetIndex == index },
                                set: { if !$0 { plateCalcSetIndex = nil } }
                            ), attachmentAnchor: .point(.top), arrowEdge: .top) {
                                PlateCalculatorPopover(
                                    target: sets[index].weight,
                                    unit: appState.profile.usesMetric ? .kg : .lb
                                )
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
            Text("×")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 0) {
                Text(L.t("repsUpper", lang))
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
                // In BW mode, weight = ADDED load. A drop set defaults
                // to 0 added (i.e., pure bodyweight rep-out). In
                // non-BW mode it's a classic 70% drop off the previous
                // working set.
                let lastWeight = useBodyweight ? 0 : (sets.last?.weight ?? 0) * 0.7
                sets.append(SetLog(weight: lastWeight, reps: 0, isDropSet: true, isBodyweight: useBodyweight))
                weightStrings.append(Self.formatWeight(lastWeight))
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text(L.t("addDropSet", lang))
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
                Text(L.t("exerciseComplete", lang))
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

            Text(L.t("newPRTitle", lang))
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(.yellow)

            Text(L.t("newPRSubtitle", lang))
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
                // Only stamp the BW flag — don't overwrite the user's
                // entered weight. In the new semantics `weight` already
                // holds the ADDED load (0 = pure BW, +X = weighted,
                // -X = assisted). Replacing it with `bodyweightValue`
                // would re-introduce the old "weight == absolute load"
                // ambiguity and break the total-load math.
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
                startRestTimer(completedWeight: sets[index].weight)
            }
        }
    }

    private func startRestTimer(completedWeight: Double = 0) {
        timer?.invalidate()
        let recentAvg = ExerciseLogService.shared.recentTopSetAverage(for: exercise.name)
        restTimerTotal = RestRecommender.recommend(
            exerciseName: exercise.name,
            repsString: exercise.reps,
            completedWeight: completedWeight,
            recentAverageWeight: recentAvg
        )
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
