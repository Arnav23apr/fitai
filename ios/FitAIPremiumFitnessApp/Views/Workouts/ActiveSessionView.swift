import SwiftUI
import AudioToolbox

/// Strong-style all-in-one active workout session. Replaces the per-exercise
/// `SetLoggingSheet` flow for templates, AI plan days, and empty workouts.
/// Each exercise is a card with its set table inline; rest timer is per-set;
/// tap the set number to assign a Warmup/Drop/Failure tag. The numeric
/// keypad is custom (StrongKeypad) — iOS's default keyboard is bypassed.
struct ActiveSessionView: View {
    @Environment(AppState.self) private var appState

    /// Initial exercises seeded from a template / empty workout. The session
    /// becomes the source of truth once started.
    let initialName: String
    let initialIcon: String
    let initialExercises: [RoutineExercise]
    let defaultRestSeconds: Int
    /// nil = ad-hoc / empty workout. Non-nil = launched from a template, used
    /// when offering "Save as Template" on finish (we already have one).
    let sourceTemplateId: String?
    /// Called when the user finishes (passing share data) or cancels (passing
    /// nil). The parent owns the post-workout flow — ActiveSessionView itself
    /// only logs work and tears down the session manager. Presentation is
    /// the parent's responsibility, which avoids the cover-on-cover dismiss
    /// race that was re-presenting fresh sessions on iOS 26.
    let onFinish: (WorkoutShareCardData?) -> Void

    @State private var workoutName: String = ""
    @State private var nameDraft: String = ""
    @State private var editingName: Bool = false
    @State private var sessionExercises: [SessionExercise] = []
    @State private var showExercisePicker: Bool = false
    @State private var showCancelConfirm: Bool = false
    @State private var showSaveTemplatePrompt: Bool = false
    @State private var setTagSheet: SetTagTarget? = nil
    @State private var restState: RestTimerState = .idle
    @State private var sessionStart: Date = Date()
    @State private var prCount: Int = 0
    @State private var prExerciseNames: [String] = []
    @State private var exerciseVolumes: [String: Double] = [:]
    @State private var didStartManager: Bool = false
    @State private var showVoiceSheet: Bool = false
    @State private var showPhotoScanner: Bool = false
    @State private var showCoachDrawer: Bool = false
    @State private var photoTargetSetId: String? = nil
    @State private var pendingPhotoCapture: UIImage? = nil
    @State private var pendingPhotoAnalysis: WeightOCRService.Result? = nil
    @State private var voiceFeedback: String? = nil
    /// Actively-edited cell. nil = no keypad shown. Plain @State (not
    /// @FocusState) so the binding propagates reliably to children — we're
    /// not interacting with iOS's text-input focus system.
    @State private var focusedField: FieldFocus? = nil
    /// Live typing buffer for the currently-focused cell. Source of truth
    /// for what the user sees while editing; parsed and written back to
    /// the model on every keystroke + on focus change.
    @State private var editingText: String = ""

    private let session = WorkoutSessionManager.shared
    private let logService = ExerciseLogService.shared

    private var weightUnit: String { appState.profile.usesMetric ? "kg" : "lbs" }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    ForEach($sessionExercises) { $sx in
                        ExerciseCard(
                            exercise: $sx,
                            weightUnit: weightUnit,
                            defaultRest: defaultRestSeconds,
                            focusedField: $focusedField,
                            editingText: editingText,
                            onTapSetNumber: { setTagSheet = SetTagTarget(exerciseId: sx.id, setId: $0) },
                            onSetCompleted: { setId, completed in
                                handleSetCompletion(exerciseId: sx.id, setId: setId, completed: completed)
                            },
                            onRemoveExercise: { removeExercise(id: sx.id) }
                        )
                    }
                    addExercisesButton
                    cancelWorkoutButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if case .running(let endsAt, _) = restState {
                        RestTimerBanner(
                            endsAt: endsAt,
                            onSkip: skipRest,
                            onAdjust: adjustRestBy
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, focusedField == nil ? 12 : 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if focusedField != nil {
                        StrongKeypad(
                            allowsDecimal: isDecimalField(focusedField),
                            onKey: handleKeypadKey
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: focusedField)
                .animation(.easeInOut(duration: 0.22), value: isResting)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            // Manual rest timer — Strong's small clock icon.
                            startManualRest(seconds: defaultRestSeconds)
                        } label: {
                            Image(systemName: "timer")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        Button {
                            focusedField = nil
                            showVoiceSheet = true
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(LinearGradient(colors: [.red, .red.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        Button {
                            focusedField = nil
                            photoTargetSetId = nil
                            showPhotoScanner = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        Button {
                            focusedField = nil
                            showCoachDrawer = true
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        focusedField = nil
                        handleFinishTapped()
                    } label: {
                        Text("Finish")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .clipShape(.capsule)
                    }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { picked in
                    addExercise(name: picked.name, muscleGroup: picked.muscleGroup)
                }
            }
            .sheet(item: $setTagSheet) { target in
                SetTagPicker(
                    current: currentTag(for: target),
                    onPick: { tag in
                        applyTag(tag, to: target)
                        setTagSheet = nil
                    }
                )
                .presentationDetents([.fraction(0.40)])
            }
            .sheet(isPresented: $showSaveTemplatePrompt) {
                SaveAsTemplatePromptSheet(
                    defaultName: workoutName,
                    onSave: { name in
                        saveSessionAsTemplate(name: name)
                        showSaveTemplatePrompt = false
                        finishAndExit()
                    },
                    onSkip: {
                        showSaveTemplatePrompt = false
                        finishAndExit()
                    }
                )
                .presentationDetents([.fraction(0.40)])
            }
            .alert("Cancel workout?", isPresented: $showCancelConfirm) {
                Button("Discard", role: .destructive) { discardWorkout() }
                Button("Keep going", role: .cancel) { }
            } message: {
                Text("All sets logged in this session will be discarded.")
            }
            .sheet(isPresented: $showVoiceSheet) {
                VoiceLogSheet { intent in
                    dispatchVoiceIntent(intent)
                }
                .environment(appState)
            }
            .sheet(isPresented: $showCoachDrawer) {
                CoachView(sessionContext: buildCoachSessionContext())
                    .environment(appState)
            }
            .fullScreenCover(isPresented: $showPhotoScanner) {
                WeightScannerView(
                    onCapture: { image in
                        showPhotoScanner = false
                        Task { await handlePhotoCapture(image) }
                    },
                    onCancel: {
                        showPhotoScanner = false
                    }
                )
            }
            .sheet(item: Binding(
                get: { pendingPhotoAnalysis.map { IdentifiedAnalysis(value: $0) } },
                set: { pendingPhotoAnalysis = $0?.value }
            )) { wrapper in
                if let img = pendingPhotoCapture {
                    WeightOCRConfirmSheet(
                        capturedImage: img,
                        analysis: wrapper.value,
                        onApply: { apply in
                            applyPhotoLog(apply)
                            pendingPhotoCapture = nil
                            pendingPhotoAnalysis = nil
                        }
                    )
                    .environment(appState)
                }
            }
            .overlay(alignment: .top) {
                if let voiceFeedback {
                    voiceFeedbackToast(voiceFeedback)
                        .padding(.top, 70)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: voiceFeedback)
            .onChange(of: focusedField) { oldValue, newValue in
                // Commit whatever was being typed in the previous cell before
                // moving on, then prime the buffer for the new cell. This is
                // what lets a user type "27." in a weight field without
                // losing the trailing decimal when they jump to reps.
                if let old = oldValue {
                    commitText(editingText, to: old)
                }
                if let new = newValue {
                    if oldValue != new {
                        editingText = textFor(new)
                    }
                } else {
                    editingText = ""
                }
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear { startIfNeeded() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if editingName {
                    TextField("Workout name", text: $nameDraft)
                        .font(.title.weight(.bold))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { commitNameEdit() }
                } else {
                    Text(workoutName)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                        .onTapGesture {
                            nameDraft = workoutName
                            editingName = true
                        }
                }
                Menu {
                    Button {
                        nameDraft = workoutName
                        editingName = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 22)
                        .background(Color.blue.opacity(0.25))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
            HStack(spacing: 12) {
                Label(formattedDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // Live elapsed timer — Text(.timer) handles its own per-second
            // refresh, so we don't depend on a manual ticker re-rendering
            // the parent view every second.
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(sessionStart, style: .timer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 8)
    }

    private var addExercisesButton: some View {
        Button {
            focusedField = nil
            showExercisePicker = true
        } label: {
            Text("Add Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.blue.opacity(0.12))
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var cancelWorkoutButton: some View {
        Button(role: .destructive) {
            focusedField = nil
            showCancelConfirm = true
        } label: {
            Text("Cancel Workout")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.red.opacity(0.10))
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var isResting: Bool {
        if case .running = restState { return true }
        return false
    }

    // MARK: - Lifecycle

    private func startIfNeeded() {
        guard !didStartManager else { return }
        didStartManager = true

        // Adopt an existing in-flight session if one exists for this
        // workout (via Resume). Otherwise start fresh.
        if session.isActive && !session.exercises.isEmpty {
            workoutName = session.workoutName
            sessionStart = session.startTime ?? Date()
            sessionExercises = session.exercises.map { ex in
                SessionExercise.fromExercise(ex, defaultRest: defaultRestSeconds)
            }
        } else {
            workoutName = initialName.isEmpty ? WorkoutSessionManager.timeOfDayWorkoutName() : initialName
            sessionExercises = initialExercises.map {
                SessionExercise.fromRoutineExercise($0, defaultRest: defaultRestSeconds)
            }
            sessionStart = Date()
            startManagerSession()
        }
    }

    private func startManagerSession() {
        let exs = sessionExercises.map { sx in
            Exercise(
                id: sx.id,
                name: sx.name,
                sets: sx.sets.count,
                reps: sx.targetReps,
                muscleGroup: sx.muscleGroup
            )
        }
        let day = WorkoutDay(
            dayLabel: sourceTemplateId == nil ? "EMPTY" : "TEMPLATE",
            name: workoutName,
            focusAreas: [],
            icon: initialIcon,
            isRestDay: false,
            exercises: exs,
            isWeakPointFocus: false
        )
        session.startWorkout(workout: day)
    }

    private func commitNameEdit() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            workoutName = trimmed
            session.workoutName = trimmed
        }
        editingName = false
    }

    // MARK: - Set actions

    private func handleSetCompletion(exerciseId: String, setId: String, completed: Bool) {
        guard let exIdx = sessionExercises.firstIndex(where: { $0.id == exerciseId }),
              let setIdx = sessionExercises[exIdx].sets.firstIndex(where: { $0.id == setId }) else { return }

        let setRow = sessionExercises[exIdx].sets[setIdx]
        if completed {
            // Confirmation chirp + haptic for the manual ✓ tap path.
            // Voice and photo paths play their own confirmation in
            // applyVoiceLogSet / applyPhotoLog after the toggle.
            playLogConfirmation()
            // PR detection (working sets only).
            if setRow.tag != .warmup && setRow.weight > 0 {
                let isPR = logService.checkForNewPR(
                    exerciseName: sessionExercises[exIdx].name,
                    weight: setRow.weight,
                    reps: setRow.reps
                )
                if isPR {
                    prCount += 1
                    if !prExerciseNames.contains(sessionExercises[exIdx].name) {
                        prExerciseNames.append(sessionExercises[exIdx].name)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            // Auto-start per-set rest timer.
            let restSec = sessionExercises[exIdx].sets[setIdx].restSeconds ?? defaultRestSeconds
            startRest(seconds: restSec)
        }
    }

    private func startRest(seconds: Int) {
        guard seconds > 0 else { return }
        let endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        restState = .running(endsAt: endsAt, total: seconds)
        session.updateRestTimer(isResting: true, secondsRemaining: seconds)
        scheduleRestClear(at: endsAt)
    }

    /// Auto-dismiss the rest banner once the countdown hits zero. Multiple
    /// concurrent schedulers are safe — each one only fires its action if
    /// the still-running endsAt matches its captured target (i.e., it
    /// "won" the race).
    private func scheduleRestClear(at endsAt: Date) {
        let target = endsAt
        let waitSeconds = max(0, target.timeIntervalSinceNow)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(waitSeconds))
            if case .running(let current, _) = restState, current == target {
                restState = .idle
                session.updateRestTimer(isResting: false, secondsRemaining: 0)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func startManualRest(seconds: Int) {
        startRest(seconds: seconds)
    }

    private func skipRest() {
        restState = .idle
        session.updateRestTimer(isResting: false, secondsRemaining: 0)
    }

    private func adjustRestBy(_ delta: Int) {
        guard case .running(let endsAt, let total) = restState else { return }
        let newEnd = endsAt.addingTimeInterval(TimeInterval(delta))
        // Don't allow rest to go negative; floor at 1s out so it'll
        // immediately tick to zero rather than display a stale value.
        let safeEnd = max(newEnd, Date().addingTimeInterval(1))
        restState = .running(endsAt: safeEnd, total: max(0, total + delta))
        let remaining = max(0, Int(safeEnd.timeIntervalSinceNow))
        session.updateRestTimer(isResting: true, secondsRemaining: remaining)
        // Schedule a fresh clear at the new endpoint. The old scheduler
        // becomes a no-op via the endsAt mismatch check.
        scheduleRestClear(at: safeEnd)
    }

    private func currentTag(for target: SetTagTarget) -> SetType {
        guard let ex = sessionExercises.first(where: { $0.id == target.exerciseId }),
              let s = ex.sets.first(where: { $0.id == target.setId }) else { return .normal }
        return s.tag
    }

    private func applyTag(_ tag: SetType, to target: SetTagTarget) {
        guard let exIdx = sessionExercises.firstIndex(where: { $0.id == target.exerciseId }),
              let setIdx = sessionExercises[exIdx].sets.firstIndex(where: { $0.id == target.setId }) else { return }
        sessionExercises[exIdx].sets[setIdx].tag = tag
    }

    private func addExercise(name: String, muscleGroup: String) {
        let routineEx = RoutineExercise(name: name, sets: 1, reps: "8-12", muscleGroup: muscleGroup)
        let sx = SessionExercise.fromRoutineExercise(routineEx, defaultRest: defaultRestSeconds)
        sessionExercises.append(sx)
        let exerciseModel = Exercise(id: sx.id, name: name, sets: 1, reps: "8-12", muscleGroup: muscleGroup)
        session.appendExercise(exerciseModel)
    }

    private func removeExercise(id: String) {
        if let field = focusedField, locateSet(field)?.0 != nil,
           sessionExercises.first(where: { $0.id == id })?.sets.contains(where: { setMatchesField($0.id, field) }) == true {
            focusedField = nil
        }
        sessionExercises.removeAll { $0.id == id }
        session.removeExercise(id: id)
    }

    private func setMatchesField(_ setId: String, _ field: FieldFocus) -> Bool {
        switch field {
        case .weight(let id), .reps(let id): return id == setId
        }
    }

    // MARK: - Finish / cancel

    /// Tap-Finish entry point. Decides whether to show the save-as-template
    /// prompt, then hands off to the parent (which owns the post-workout
    /// share overlay).
    private func handleFinishTapped() {
        // Commit in-flight buffer.
        if let field = focusedField {
            commitText(editingText, to: field)
            focusedField = nil
        }

        let hasContent = sessionExercises.contains { ex in
            ex.sets.contains(where: \.isCompleted)
        }

        // Empty session → just confirm and discard. No share screen.
        guard hasContent else {
            showCancelConfirm = true
            return
        }

        // Persist logs + drive PR detection now so the share data is
        // accurate by the time we build it.
        persistAllLogs()

        // Decide whether to offer Save-as-Template. Skip if the session was
        // launched from an existing template or the user is at the free cap.
        let canOfferSave = sourceTemplateId == nil
            && !RoutineService.shared.atFreeCap(isPremium: appState.profile.isPremium)
        if canOfferSave {
            showSaveTemplatePrompt = true
        } else {
            finishAndExit()
        }
    }

    /// Save logs to ExerciseLogService + populate PR tracking. Runs once
    /// at finish-time so the share screen has accurate PR data.
    private func persistAllLogs() {
        for sx in sessionExercises {
            let completedSets = sx.sets.filter(\.isCompleted).map { $0.toSetLog() }
            guard !completedSets.isEmpty else { continue }
            let log = ExerciseLog(
                exerciseName: sx.name,
                muscleGroup: sx.muscleGroup,
                date: Date(),
                sets: completedSets,
                totalVolume: completedSets
                    .filter(\.countsTowardVolume)
                    .reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            )
            logService.saveLog(log)
            exerciseVolumes[sx.id] = log.totalVolume
        }
    }

    private func saveSessionAsTemplate(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !sessionExercises.isEmpty else { return }
        let routine = Routine(
            name: trimmed,
            icon: initialIcon,
            exercises: sessionExercises.map { sx in
                RoutineExercise(
                    name: sx.name,
                    sets: sx.sets.count,
                    reps: sx.targetReps,
                    muscleGroup: sx.muscleGroup
                )
            },
            defaultRestSeconds: defaultRestSeconds
        )
        _ = RoutineService.shared.save(routine, isPremium: appState.profile.isPremium)
    }

    /// Successful-finish path: log to AppState, mirror to Health, end the
    /// session manager, hand share data to the parent via `onFinish`. The
    /// parent dismisses ActiveSessionView's cover and then presents the
    /// share overlay — sequencing them this way avoids the iOS 26
    /// cover-on-cover dismiss bug that was re-presenting empty sessions.
    private func finishAndExit() {
        let durationMin = max(1, Int(Date().timeIntervalSince(sessionStart)) / 60)
        let completedNames = sessionExercises
            .filter { $0.sets.contains(where: \.isCompleted) }
            .map(\.name)
        let exercisesCompleted = completedNames.count
        appState.logWorkout(
            dayName: workoutName,
            exercisesCompleted: exercisesCompleted,
            totalExercises: sessionExercises.count,
            durationMinutes: durationMin,
            completedExerciseNames: completedNames
        )
        HealthKitWorkoutExporter.shared.save(
            startDate: sessionStart,
            durationSeconds: max(Int(Date().timeIntervalSince(sessionStart)), 60),
            exerciseCount: exercisesCompleted
        )

        let shareData = buildShareData()
        session.endSession()
        clearLocalState()
        onFinish(shareData)
    }

    private func discardWorkout() {
        session.endSession()
        clearLocalState()
        onFinish(nil)
    }

    private func clearLocalState() {
        sessionExercises = []
        prCount = 0
        prExerciseNames = []
        exerciseVolumes = [:]
    }

    // MARK: - Share data

    private func buildShareData() -> WorkoutShareCardData {
        let totalVolume = exerciseVolumes.values.reduce(0, +)

        let allLogs = logService.loadAll()
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayLogs = allLogs.filter { $0.date >= todayStart }

        var topExName = ""
        var topWeight: Double = 0
        var topReps: Int = 0
        for log in todayLogs {
            for s in log.sets where s.isCompleted && s.setType != .warmup {
                if s.weight > topWeight {
                    topWeight = s.weight
                    topReps = s.reps
                    topExName = log.exerciseName
                }
            }
        }

        // PR details: compare today's best vs all-time previous best.
        var prDetailsList: [PRDetail] = []
        for prName in prExerciseNames {
            let todayExLogs = todayLogs.filter { $0.exerciseName == prName }
            let todayBestSet = todayExLogs
                .flatMap(\.sets)
                .filter { $0.isCompleted && $0.setType != .warmup }
                .max(by: { $0.weight < $1.weight })
            let previousLogs = allLogs.filter { $0.exerciseName == prName && $0.date < todayStart }
            let previousBestSet = previousLogs
                .flatMap(\.sets)
                .filter { $0.isCompleted && $0.setType != .warmup }
                .max(by: { $0.weight < $1.weight })

            if let now = todayBestSet, now.weight > 0 {
                prDetailsList.append(PRDetail(
                    exerciseName: prName,
                    newWeight: now.weight,
                    newReps: now.reps,
                    previousWeight: previousBestSet?.weight ?? 0,
                    previousReps: previousBestSet?.reps ?? 0
                ))
            }
        }

        let totalSets = sessionExercises.reduce(0) { running, ex in
            running + ex.sets.filter { $0.isCompleted && $0.tag != .warmup }.count
        }
        let durationMin = max(1, Int(Date().timeIntervalSince(sessionStart)) / 60)
        let estimatedCal = Int(Double(durationMin) * 5.5 + totalVolume * 0.015)

        let completedExercises: [Exercise] = sessionExercises
            .filter { $0.sets.contains(where: \.isCompleted) }
            .map { sx in
                Exercise(
                    id: sx.id,
                    name: sx.name,
                    sets: sx.sets.filter(\.isCompleted).count,
                    reps: sx.targetReps,
                    muscleGroup: sx.muscleGroup
                )
            }

        let bestWeight = prExerciseNames.first.map { logService.history(for: $0).personalBestWeight } ?? 0
        let bestReps = prExerciseNames.first.map { logService.history(for: $0).personalBestReps } ?? 0

        return WorkoutShareCardData(
            workoutName: workoutName,
            focusAreas: [],
            totalVolume: totalVolume,
            duration: durationMin,
            exercisesCompleted: completedExercises.count,
            totalExercises: sessionExercises.count,
            totalSets: totalSets,
            prCount: prCount,
            prExerciseNames: prExerciseNames,
            pointsEarned: 100 + (completedExercises.count * 10) + (prCount * 50),
            prBestWeight: bestWeight,
            prBestReps: bestReps,
            weightUnit: appState.profile.usesMetric ? "kg" : "lbs",
            topSetExercise: topExName,
            topSetWeight: topWeight,
            topSetReps: topReps,
            estimatedCalories: estimatedCal,
            exercises: completedExercises,
            workoutDate: Date(),
            prDetails: prDetailsList
        )
    }

    // MARK: - Custom keypad routing

    private func isDecimalField(_ field: FieldFocus?) -> Bool {
        guard let field else { return false }
        if case .weight = field { return true }
        return false
    }

    private func handleKeypadKey(_ key: StrongKeypad.Key) {
        guard let field = focusedField else { return }
        switch key {
        case .digit(let s):
            // Cap to a reasonable length to avoid runaway typing.
            guard editingText.count < 7 else { return }
            // Replace a leading single "0" so users typing "0" then "5"
            // get "5" not "05" (and Double parses identically anyway).
            if editingText == "0" {
                editingText = s
            } else {
                editingText += s
            }
            commitText(editingText, to: field)
        case .dot:
            guard isDecimalField(field), !editingText.contains(".") else { return }
            editingText = editingText.isEmpty ? "0." : editingText + "."
            // Don't commit — Double("0.") parses fine but the trailing
            // dot needs to live in the buffer until a digit follows.
        case .backspace:
            editingText = String(editingText.dropLast())
            commitText(editingText, to: field)
        case .adjust(let delta):
            adjustField(field, by: delta)
            // Reload buffer from the freshly-mutated model.
            editingText = textFor(field)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .next:
            commitText(editingText, to: field)
            advanceFocus()
        case .dismiss:
            commitText(editingText, to: field)
            focusedField = nil
        }
    }

    private func adjustField(_ field: FieldFocus, by delta: Double) {
        guard let (exIdx, setIdx) = locateSet(field) else { return }
        switch field {
        case .weight:
            let next = max(0, sessionExercises[exIdx].sets[setIdx].weight + delta)
            sessionExercises[exIdx].sets[setIdx].weight = next
        case .reps:
            let next = max(0, sessionExercises[exIdx].sets[setIdx].reps + Int(delta))
            sessionExercises[exIdx].sets[setIdx].reps = next
        }
    }

    /// weight → reps (same set) → weight (next set, same exercise) →
    /// weight (first set, next exercise) → unfocus.
    private func advanceFocus() {
        guard let field = focusedField, let (exIdx, setIdx) = locateSet(field) else { return }
        if case .weight = field {
            focusedField = .reps(setId: sessionExercises[exIdx].sets[setIdx].id)
            return
        }
        if setIdx + 1 < sessionExercises[exIdx].sets.count {
            focusedField = .weight(setId: sessionExercises[exIdx].sets[setIdx + 1].id)
            return
        }
        if exIdx + 1 < sessionExercises.count, let firstSet = sessionExercises[exIdx + 1].sets.first {
            focusedField = .weight(setId: firstSet.id)
            return
        }
        focusedField = nil
    }

    private func locateSet(_ field: FieldFocus) -> (Int, Int)? {
        let setId: String
        switch field {
        case .weight(let id), .reps(let id): setId = id
        }
        for (ei, ex) in sessionExercises.enumerated() {
            if let si = ex.sets.firstIndex(where: { $0.id == setId }) {
                return (ei, si)
            }
        }
        return nil
    }

    private func textFor(_ field: FieldFocus) -> String {
        guard let (e, s) = locateSet(field) else { return "" }
        switch field {
        case .weight:
            let w = sessionExercises[e].sets[s].weight
            return w > 0 ? formatWeight(w) : ""
        case .reps:
            let r = sessionExercises[e].sets[s].reps
            return r > 0 ? "\(r)" : ""
        }
    }

    private func commitText(_ text: String, to field: FieldFocus) {
        guard let (e, s) = locateSet(field) else { return }
        switch field {
        case .weight:
            // Trailing dot ("27.") parses as 27.0 — fine, we keep the
            // buffer for display but model stores the parsed value.
            sessionExercises[e].sets[s].weight = Double(text) ?? 0
        case .reps:
            sessionExercises[e].sets[s].reps = Int(text) ?? 0
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value == 0 { return "" }
        return value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: Date())
    }

    // MARK: - Voice intent dispatch

    private func voiceFeedbackToast(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    /// Routes a parsed voice intent to the correct mutation. Each branch
    /// is a one-liner — the actual mutation logic lives on this view's
    /// existing methods.
    private func dispatchVoiceIntent(_ intent: VoiceIntent) {
        switch intent {
        case .logSet(let log):
            applyVoiceLogSet(log)
        case .logMultiple(let count, let weight, let reps):
            applyVoiceLogMultiple(count: count, weight: weight, reps: reps)
        case .repeatLast:
            applyVoiceRepeatLast()
        case .tagSet(let tag):
            applyVoiceTag(tag)
        case .structure(.addSet(let tag)):
            if let exIdx = sessionExercises.firstIndex(where: { _ in true }) {
                appendSetToExercise(at: exIdx, tag: tag)
            }
            flashFeedback(tag == .warmup ? "Warmup set added" : "Set added")
        case .structure(.removeLastSet):
            if !sessionExercises.isEmpty,
               let lastEx = sessionExercises.indices.last,
               !sessionExercises[lastEx].sets.isEmpty {
                sessionExercises[lastEx].sets.removeLast()
                flashFeedback("Removed last set")
            }
        case .structure(.addExercise(let name)):
            addExercise(name: name, muscleGroup: "")
            flashFeedback("Added \(name)")
        case .structure(.replaceExercise(let from, let to)):
            if let idx = sessionExercises.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(from) }) {
                sessionExercises[idx].name = to
                flashFeedback("Swapped \(from) → \(to)")
            }
        case .structure(.skipExercise), .structure(.nextExercise):
            advanceToNextExercise()
        case .rest(.start(let s)):
            startRest(seconds: s)
            flashFeedback("Rest \(s)s")
        case .rest(.adjust(let d)):
            adjustRestBy(d)
            flashFeedback(d > 0 ? "+\(d)s rest" : "\(d)s rest")
        case .rest(.skip):
            skipRest()
            flashFeedback("Rest skipped")
        case .query(let q):
            speakQueryResponse(q)
        case .session(.finish):
            handleFinishTapped()
        case .session(.cancel):
            showCancelConfirm = true
        case .session(.saveAsTemplate):
            // Defer to existing finish flow which offers save-as-template.
            handleFinishTapped()
        case .unit(let metric):
            // Toggle local profile copy for the active workout. Persisted
            // on next saveProfile.
            appState.profile.usesMetric = metric
            appState.saveProfile()
            flashFeedback("Switched to \(metric ? "kg" : "lbs")")
        case .unrecognized(let t):
            flashFeedback("Didn't catch \"\(t)\"")
        }
    }

    private func applyVoiceLogSet(_ log: VoiceIntent.LogSet) {
        guard !sessionExercises.isEmpty else {
            flashFeedback("Add an exercise first")
            return
        }
        // Default to current/active exercise = the first non-fully-completed.
        guard let exIdx = sessionExercises.firstIndex(where: { ex in
            !ex.sets.allSatisfy(\.isCompleted)
        }) ?? sessionExercises.indices.first else { return }

        // Resolve set index from position.
        let setIdx: Int = {
            switch log.position {
            case .first?: return 0
            case .second?: return 1
            case .third?: return 2
            case .fourth?: return 3
            case .fifth?: return 4
            case .sixth?: return 5
            case .specific(let n)?: return max(0, n - 1)
            case .nextEmpty?, nil:
                return sessionExercises[exIdx].sets.firstIndex(where: { !$0.isCompleted }) ?? sessionExercises[exIdx].sets.count
            }
        }()

        // Ensure enough rows exist.
        while sessionExercises[exIdx].sets.count <= setIdx {
            appendSetToExercise(at: exIdx, tag: nil)
        }

        if let w = log.weight, w > 0 {
            sessionExercises[exIdx].sets[setIdx].weight = w
        }
        if log.reps > 0 {
            sessionExercises[exIdx].sets[setIdx].reps = log.reps
        }
        if let tag = log.tag {
            sessionExercises[exIdx].sets[setIdx].tag = tag
        }
        sessionExercises[exIdx].sets[setIdx].isCompleted = true
        handleSetCompletion(
            exerciseId: sessionExercises[exIdx].id,
            setId: sessionExercises[exIdx].sets[setIdx].id,
            completed: true
        )
        // Confirmation chirp + haptic instead of a text toast.
        // Phone-face-down workflow: user hears a short tink and feels a
        // success bump, no need to look at the screen. Research-validated
        // pattern from Vora / GhostFit reviews.
        playLogConfirmation()
    }

    /// "five sets of five at 225" — fills N sets at the given weight/reps
    /// and marks them complete. Used after warmups when the user knows
    /// they're committing to a target. Each set still kicks off the rest
    /// timer for the LAST set logged (the others are batch-applied so
    /// they don't all start countdowns).
    private func applyVoiceLogMultiple(count: Int, weight: Double, reps: Int) {
        guard !sessionExercises.isEmpty else {
            flashFeedback("Add an exercise first")
            return
        }
        guard let exIdx = sessionExercises.firstIndex(where: { ex in
            !ex.sets.allSatisfy(\.isCompleted)
        }) ?? sessionExercises.indices.first else { return }

        // Make sure there are enough rows.
        while sessionExercises[exIdx].sets.filter({ !$0.isCompleted }).count < count {
            appendSetToExercise(at: exIdx, tag: nil)
        }

        var filled = 0
        for setIdx in sessionExercises[exIdx].sets.indices {
            guard !sessionExercises[exIdx].sets[setIdx].isCompleted else { continue }
            guard filled < count else { break }
            sessionExercises[exIdx].sets[setIdx].weight = weight
            sessionExercises[exIdx].sets[setIdx].reps = reps
            sessionExercises[exIdx].sets[setIdx].isCompleted = true
            filled += 1
        }

        // PR check on the heaviest one (they're all the same here).
        let isPR = logService.checkForNewPR(
            exerciseName: sessionExercises[exIdx].name,
            weight: weight,
            reps: reps
        )
        if isPR {
            prCount += 1
            if !prExerciseNames.contains(sessionExercises[exIdx].name) {
                prExerciseNames.append(sessionExercises[exIdx].name)
            }
        }
        // Start a single rest timer (post-final-set) instead of one per
        // set, since we just batch-logged.
        let restSec = sessionExercises[exIdx].sets.last?.restSeconds ?? defaultRestSeconds
        startRest(seconds: restSec)
        playLogConfirmation()
    }

    /// "same again" / "repeat" — copies the last completed set's
    /// weight + reps onto the next empty set and marks it complete.
    /// Useful for AMRAP and drop-set sequences where the user just wants
    /// to log "another one" hands-free.
    private func applyVoiceRepeatLast() {
        guard let exIdx = sessionExercises.firstIndex(where: { ex in
            !ex.sets.allSatisfy(\.isCompleted)
        }) ?? sessionExercises.indices.first else { return }
        guard let lastCompleted = sessionExercises[exIdx].sets.last(where: \.isCompleted) else {
            flashFeedback("Nothing to repeat yet")
            return
        }
        // Find or create the next empty set.
        let setIdx: Int
        if let idx = sessionExercises[exIdx].sets.firstIndex(where: { !$0.isCompleted }) {
            setIdx = idx
        } else {
            appendSetToExercise(at: exIdx, tag: lastCompleted.tag)
            setIdx = sessionExercises[exIdx].sets.count - 1
        }
        sessionExercises[exIdx].sets[setIdx].weight = lastCompleted.weight
        sessionExercises[exIdx].sets[setIdx].reps = lastCompleted.reps
        sessionExercises[exIdx].sets[setIdx].tag = lastCompleted.tag
        sessionExercises[exIdx].sets[setIdx].isCompleted = true
        let restSec = sessionExercises[exIdx].sets[setIdx].restSeconds ?? defaultRestSeconds
        startRest(seconds: restSec)
        playLogConfirmation()
    }

    private func applyVoiceTag(_ tag: VoiceIntent.TagSet) {
        guard let exIdx = sessionExercises.firstIndex(where: { ex in
            !ex.sets.allSatisfy(\.isCompleted)
        }) ?? sessionExercises.indices.first else { return }
        let setIdx: Int = {
            switch tag.position {
            case .first: return 0
            case .second: return 1
            case .third: return 2
            case .fourth: return 3
            case .fifth: return 4
            case .sixth: return 5
            case .specific(let n): return max(0, n - 1)
            case .nextEmpty:
                // "this set" / "last set" → focused or last completed
                if let f = focusedField, let (_, s) = locateSet(f) { return s }
                return sessionExercises[exIdx].sets.lastIndex(where: { $0.isCompleted }) ?? 0
            }
        }()
        guard sessionExercises[exIdx].sets.indices.contains(setIdx) else { return }
        sessionExercises[exIdx].sets[setIdx].tag = tag.tag
        flashFeedback("Tagged set \(setIdx + 1) as \(tag.tag.label)")
    }

    private func appendSetToExercise(at exIdx: Int, tag: SetType?) {
        let lastSet = sessionExercises[exIdx].sets.last
        let nextIndex = (lastSet?.index ?? 0) + 1
        let new = SessionSet(
            index: nextIndex,
            previousWeight: lastSet?.previousWeight ?? 0,
            previousReps: lastSet?.previousReps ?? 0,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
            tag: tag ?? .normal,
            isCompleted: false,
            restSeconds: lastSet?.restSeconds ?? defaultRestSeconds
        )
        sessionExercises[exIdx].sets.append(new)
    }

    private func advanceToNextExercise() {
        // Mark the current one fully complete and move focus.
        guard let exIdx = sessionExercises.firstIndex(where: { ex in
            !ex.sets.allSatisfy(\.isCompleted)
        }) else { return }
        for i in sessionExercises[exIdx].sets.indices {
            sessionExercises[exIdx].sets[i].isCompleted = true
        }
        flashFeedback("Skipped \(sessionExercises[exIdx].name)")
    }

    private func speakQueryResponse(_ q: VoiceIntent.Query) {
        var msg = ""
        switch q {
        case .lastSession:
            // Use the first un-fully-completed exercise as context.
            if let ex = sessionExercises.first(where: { !$0.sets.allSatisfy(\.isCompleted) }),
               let last = logService.lastSession(for: ex.name) {
                let bestSet = last.sets.filter(\.countsTowardVolume).max(by: { $0.weight < $1.weight })
                if let s = bestSet {
                    msg = "Last \(ex.name): \(formatWeight(s.weight)) for \(s.reps) reps"
                } else {
                    msg = "No prior set for \(ex.name)"
                }
            } else {
                msg = "No prior workouts on this exercise"
            }
        case .personalRecord:
            if let ex = sessionExercises.first(where: { !$0.sets.allSatisfy(\.isCompleted) }) {
                let pr = logService.personalBestWeight(for: ex.name)
                msg = pr > 0 ? "Your \(ex.name) PR is \(formatWeight(pr))" : "No PR yet on \(ex.name)"
            } else {
                msg = "Pick an exercise first"
            }
        case .elapsedTime:
            let secs = Int(Date().timeIntervalSince(sessionStart))
            msg = "\(secs / 60) minutes in"
        case .nextExercise:
            if let ex = sessionExercises.first(where: { !$0.sets.allSatisfy(\.isCompleted) }) {
                msg = "Up next: \(ex.name)"
            } else {
                msg = "All done. Finish workout?"
            }
        case .restRemaining:
            if case .running(let endsAt, _) = restState {
                let s = max(0, Int(endsAt.timeIntervalSinceNow))
                msg = "\(s) seconds left"
            } else {
                msg = "No rest running"
            }
        }
        flashFeedback(msg)
    }

    private func flashFeedback(_ message: String) {
        voiceFeedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if voiceFeedback == message { voiceFeedback = nil }
        }
    }

    /// Short confirmation tink + success haptic. Used after successful
    /// set logs so the user gets non-visual feedback (phone face-down on
    /// the bench). 1057 = "Tink" SystemSoundID, the cleanest of Apple's
    /// built-ins for a "logged" cue.
    private func playLogConfirmation() {
        AudioServicesPlaySystemSound(1057)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Snapshot of the active session for Coach drawer. Lets Coach answer
    /// "what did I just do?" / "should I bump weight?" questions with real
    /// context instead of asking the user to retype it.
    private func buildCoachSessionContext() -> String {
        var lines: [String] = ["The user is mid-workout. Active session state:"]
        lines.append("Workout: \(workoutName)")
        let elapsed = Int(Date().timeIntervalSince(sessionStart))
        lines.append("Elapsed: \(elapsed / 60)m \(elapsed % 60)s")
        for (i, ex) in sessionExercises.enumerated() {
            lines.append("\nExercise \(i + 1): \(ex.name)")
            for s in ex.sets {
                let status = s.isCompleted ? "✓" : "_"
                let w = s.weight > 0 ? formatWeight(s.weight) : "?"
                let r = s.reps > 0 ? "\(s.reps)" : "?"
                let tag = s.tag == .normal ? "" : " [\(s.tag.label)]"
                lines.append("  Set \(s.index): \(w) × \(r) \(status)\(tag)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Photo flow

    @MainActor
    private func handlePhotoCapture(_ image: UIImage) async {
        pendingPhotoCapture = image
        let result = await WeightOCRService.shared.analyze(
            image: image,
            profile: appState.profile
        )
        pendingPhotoAnalysis = result
    }

    /// Writes the photo result into the session — either populates the cell
    /// the user tapped from, or appends a fresh set on the matching
    /// exercise (creating the exercise if it doesn't exist yet).
    private func applyPhotoLog(_ apply: WeightOCRConfirmSheet.Apply) {
        // 1. Find or create the exercise.
        var exIdx: Int
        if let existing = sessionExercises.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(apply.exercise) || apply.exercise.localizedCaseInsensitiveContains($0.name) }) {
            exIdx = existing
        } else {
            addExercise(name: apply.exercise, muscleGroup: "")
            exIdx = sessionExercises.count - 1
        }

        // 2. Place the value — into the cell the user tapped from, if any;
        //    otherwise the next un-completed set.
        let setIdx: Int
        if let targetSetId = photoTargetSetId,
           let foundIdx = sessionExercises[exIdx].sets.firstIndex(where: { $0.id == targetSetId }) {
            setIdx = foundIdx
        } else if let nextEmpty = sessionExercises[exIdx].sets.firstIndex(where: { !$0.isCompleted }) {
            setIdx = nextEmpty
        } else {
            // All sets done — append a new one.
            appendSetToExercise(at: exIdx, tag: nil)
            setIdx = sessionExercises[exIdx].sets.count - 1
        }

        sessionExercises[exIdx].sets[setIdx].weight = apply.weight
        sessionExercises[exIdx].sets[setIdx].reps = apply.reps
        sessionExercises[exIdx].sets[setIdx].isCompleted = true
        handleSetCompletion(
            exerciseId: sessionExercises[exIdx].id,
            setId: sessionExercises[exIdx].sets[setIdx].id,
            completed: true
        )
        photoTargetSetId = nil
        playLogConfirmation()
    }
}

/// Sheet binding wrapper — Identifiable shim so we can drive a sheet
/// from a non-Identifiable struct (`WeightOCRService.Result`).
private struct IdentifiedAnalysis: Identifiable {
    let id = UUID()
    let value: WeightOCRService.Result
}

// MARK: - Session-local exercise state

/// In-memory shape for one exercise within an active session. Mirrors
/// `RoutineExercise` but carries per-set logging data and is mutated freely
/// during the session. Persisted lightly via WorkoutSessionManager.
struct SessionExercise: Identifiable, Equatable {
    let id: String
    var name: String
    var muscleGroup: String
    var targetReps: String
    var sets: [SessionSet]

    static func fromRoutineExercise(_ ex: RoutineExercise, defaultRest: Int) -> SessionExercise {
        let lastSession = ExerciseLogService.shared.lastSession(for: ex.name)
        var rows: [SessionSet] = []
        for i in 0..<ex.sets {
            let prevWeight = lastSession?.sets[safe: i]?.weight ?? 0
            let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
            // Leave actual weight/reps at 0 so the cell renders the
            // historical value as a MUTED suggestion. Tapping ✓ accepts
            // the suggestion (handled in handleSetCompletion); typing a
            // new value overrides it. This is the Vora / GhostFit
            // "auto-fill" pattern that reviewers describe as the single
            // biggest "this app knows me" win.
            rows.append(SessionSet(
                index: i + 1,
                previousWeight: prevWeight,
                previousReps: prevReps,
                weight: 0,
                reps: 0,
                tag: .normal,
                isCompleted: false,
                restSeconds: ex.restSecondsOverride ?? defaultRest
            ))
        }
        return SessionExercise(
            id: ex.id,
            name: ex.name,
            muscleGroup: ex.muscleGroup,
            targetReps: ex.reps,
            sets: rows
        )
    }

    static func fromExercise(_ ex: Exercise, defaultRest: Int) -> SessionExercise {
        let lastSession = ExerciseLogService.shared.lastSession(for: ex.name)
        var rows: [SessionSet] = []
        for i in 0..<ex.sets {
            // Suggestion priority: actual previous-session value first,
            // AI-plan suggestedWeights/Reps second. Both stored on
            // `previous*` so the row can render them as a muted
            // suggestion until user types or ✓.
            let prevWeight = lastSession?.sets[safe: i]?.weight ?? 0
            let prevReps = lastSession?.sets[safe: i]?.reps ?? 0
            let suggestedW = prevWeight > 0 ? prevWeight : (ex.suggestedWeights[safe: i] ?? 0)
            let suggestedR = prevReps > 0 ? prevReps : (ex.suggestedReps[safe: i] ?? 0)
            rows.append(SessionSet(
                index: i + 1,
                previousWeight: suggestedW,
                previousReps: suggestedR,
                weight: 0,
                reps: 0,
                tag: .normal,
                isCompleted: false,
                restSeconds: defaultRest
            ))
        }
        return SessionExercise(
            id: ex.id,
            name: ex.name,
            muscleGroup: ex.muscleGroup,
            targetReps: ex.reps,
            sets: rows
        )
    }
}

/// One row in the set table.
struct SessionSet: Identifiable, Equatable {
    let id: String
    var index: Int
    var previousWeight: Double
    var previousReps: Int
    var weight: Double
    var reps: Int
    var tag: SetType
    var isCompleted: Bool
    var restSeconds: Int?

    init(
        id: String = UUID().uuidString,
        index: Int,
        previousWeight: Double = 0,
        previousReps: Int = 0,
        weight: Double = 0,
        reps: Int = 0,
        tag: SetType = .normal,
        isCompleted: Bool = false,
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.index = index
        self.previousWeight = previousWeight
        self.previousReps = previousReps
        self.weight = weight
        self.reps = reps
        self.tag = tag
        self.isCompleted = isCompleted
        self.restSeconds = restSeconds
    }

    func toSetLog() -> SetLog {
        SetLog(
            weight: weight,
            reps: reps,
            isCompleted: isCompleted,
            isFailure: tag == .failure,
            isDropSet: tag == .dropSet,
            timestamp: Date(),
            setType: tag,
            rpe: nil,
            restSeconds: restSeconds
        )
    }
}

struct SetTagTarget: Identifiable {
    var id: String { "\(exerciseId)-\(setId)" }
    let exerciseId: String
    let setId: String
}

enum RestTimerState: Equatable {
    case idle
    case running(endsAt: Date, total: Int)
}
