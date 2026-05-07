import SwiftUI
import MuscleMap

struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let workout: WorkoutDay

    private let session = WorkoutSessionManager.shared
    private let logService = ExerciseLogService.shared

    @State private var selectedExercise: Exercise? = nil
    @State private var demoExercise: Exercise? = nil
    @State private var showWhyWorkout: Bool = false
    @State private var whyExplanation: String = ""
    @State private var isLoadingWhy: Bool = false
    @State private var showPointsFloat: Bool = false
    @State private var floatingPoints: Int = 0
    @State private var completionAnimating: Bool = false
    @State private var shareData: IdentifiableShareData? = nil
    @State private var selectedMuscle: Muscle? = nil
    @State private var pendingShareData: WorkoutShareCardData? = nil
    @State private var finishCountdown: Int = 8
    @State private var finishTimer: Timer? = nil
    @State private var showDiscardConfirm: Bool = false
    @State private var showRestartConfirm: Bool = false
    @State private var showEditFinished: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    private var workoutStarted: Bool { session.isActive && session.workoutName == workout.name }
    private var completedExercises: Set<String> { session.completedExerciseIds }
    private var elapsedSeconds: Int { session.elapsedSeconds }
    private var earnedPRPoints: Int { session.earnedPRPoints }
    private var exercisePRs: Set<String> { session.exercisePRs }
    private var prExerciseNames: [String] { session.prExerciseNames }
    private var exerciseVolumes: [String: Double] { session.exerciseVolumes }

    private var allCompleted: Bool {
        completedExercises.count == workout.exercises.count && !workout.exercises.isEmpty
    }

    private var isAlreadyDone: Bool {
        appState.isDayCompleted(workout.dayLabel)
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets }
    }

    private var estimatedTime: String {
        let minutes = totalSets * 3
        return "\(minutes)min"
    }

    private var difficultyLevel: Int {
        if totalSets >= 24 { return 5 }
        if totalSets >= 20 { return 4 }
        if totalSets >= 14 { return 3 }
        if totalSets >= 8 { return 2 }
        return 1
    }

    private var musclesTargeted: [String] {
        Array(Set(workout.exercises.map(\.muscleGroup))).sorted()
    }

    private var workoutPoints: Int {
        100 + (completedExercises.count * 10) + earnedPRPoints
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard

                    if workoutStarted || isAlreadyDone {
                        progressCard
                    }

                    whyThisWorkoutButton

                    if showWhyWorkout {
                        whyExplanationCard
                    }

                    WorkoutMuscleMapView(
                        exercises: workout.exercises,
                        onMuscleTapped: { muscle in
                            selectedMuscle = muscle
                        }
                    )

                    exercisesList

                    if !workout.isRestDay && !isAlreadyDone {
                        actionButton
                    } else if !workout.isRestDay && isAlreadyDone {
                        alreadyDoneActions
                    }

                    pointsPreview
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                        .fontWeight(.medium)
                }
                if workoutStarted && !isAlreadyDone {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) {
                            showDiscardConfirm = true
                        } label: {
                            Label(L.t("endWorkoutBtn", lang), systemImage: "xmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                SetLoggingSheet(exercise: exercise) { completedSets, hitPR in
                    handleExerciseCompletion(exercise: exercise, sets: completedSets, hitPR: hitPR)
                }
            }
            .sheet(item: $selectedMuscle) { muscle in
                MuscleDetailSheet(
                    muscle: muscle,
                    exercises: workout.exercises,
                    exerciseLogs: logService.loadAll()
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $demoExercise) { exercise in
                ExerciseDetailSheet(exercise: exercise)
                    .presentationDetents([.large])
            }
            .sensoryFeedback(.success, trigger: shareData != nil)
            .confirmationDialog(
                L.t("endWorkoutTitle", lang),
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                if completedExercises.count > 0 {
                    Button(L.t("saveAndFinish", lang)) { completeWorkout() }
                }
                Button(L.t("discardWorkout", lang), role: .destructive) {
                    session.endSession()
                }
                Button(L.t("keepGoing", lang), role: .cancel) { }
            } message: {
                if completedExercises.count > 0 {
                    Text(String(format: L.t("endWorkoutMsgPartial", lang),
                                "\(completedExercises.count)" as NSString,
                                "\(workout.exercises.count)" as NSString))
                } else {
                    Text(L.t("endWorkoutMsgEmpty", lang))
                }
            }
            .confirmationDialog(
                L.t("restartWorkoutTitle", lang),
                isPresented: $showRestartConfirm,
                titleVisibility: .visible
            ) {
                Button(L.t("restart", lang), role: .destructive) { restartWorkout() }
                Button(L.t("cancel", lang), role: .cancel) { }
            } message: {
                Text(L.t("restartWorkoutMsg", lang))
            }
            .sheet(isPresented: $showEditFinished) {
                EditFinishedWorkoutSheet(exercises: workout.exercises)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .overlay(alignment: .top) {
            if showPointsFloat {
                pointsFloatView
            }
        }
        .overlay(alignment: .bottom) {
            if session.isPendingFinish {
                WorkoutCompletionToast(
                    secondsRemaining: finishCountdown,
                    onUndo: {
                        withAnimation(.snappy(duration: 0.3)) { undoFinish() }
                    },
                    onDone: { commitFinish() }
                )
                .padding(.bottom, 24)
            }
        }
        .animation(.snappy(duration: 0.3), value: session.isPendingFinish)
        .onDisappear {
            // If user closes the sheet during the grace period, commit so we
            // don't silently drop the workout.
            if session.isPendingFinish { commitFinish() }
        }
        .fullScreenCover(item: $shareData) { data in
            WorkoutShareOverlay(
                data: data.data,
                onDismiss: {
                    shareData = nil
                    dismiss()
                }
            )
            .background(ClearBackground())
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            workout.isWeakPointFocus ?
                            Color.orange.opacity(0.12) : Color.blue.opacity(0.12)
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: workout.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(workout.isWeakPointFocus ? .orange : .blue)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                        if workout.isWeakPointFocus {
                            Text(L.t("focusBadge", lang))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(.capsule)
                        }
                        if isAlreadyDone {
                            Text(L.t("doneBadge", lang))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .clipShape(.capsule)
                        }
                    }
                    Text(workout.focusAreas.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                miniStat(value: "\(workout.exercises.count)", label: L.t("exercisesLabel", lang), icon: "list.bullet", color: .blue)
                miniDivider
                miniStat(value: "\(totalSets)", label: L.t("totalSetsLabel", lang), icon: "square.stack.fill", color: .purple)
                miniDivider
                miniStat(value: estimatedTime, label: L.t("estTime", lang), icon: "clock.fill", color: .green)
                miniDivider
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < difficultyLevel ? "flame.fill" : "flame")
                                .font(.system(size: 8))
                                .foregroundStyle(i < difficultyLevel ? .orange : Color(.quaternaryLabel))
                        }
                    }
                    Text(L.t("difficulty", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }

            if workout.isWeakPointFocus {
                HStack(spacing: 8) {
                    Image(systemName: "brain.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("AI Note: \(aiNote)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(10)
                .background(Color.cyan.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var aiNote: String {
        let focus = workout.focusAreas.joined(separator: " & ")
        if workout.name.lowercased().contains("push") {
            return "Chest priority day: emphasize upper chest for V-taper development"
        }
        if workout.name.lowercased().contains("pull") {
            return "Back width focus: lat pulldowns and rows build your V-taper"
        }
        if workout.name.lowercased().contains("leg") {
            return "Foundation day: compound leg movements boost testosterone"
        }
        if workout.name.lowercased().contains("weak") {
            return "Extra volume on \(focus) to accelerate lagging areas"
        }
        return "\(focus) targeted for balanced development"
    }

    private func miniStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 36)
    }

    // MARK: - Progress

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAlreadyDone ? L.t("completedStatus", lang) : L.t("inProgress", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isAlreadyDone ? .green : .primary)
                    if workoutStarted && !isAlreadyDone {
                        Text(session.formatTime(elapsedSeconds))
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completedExercises.count)/\(workout.exercises.count)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(allCompleted || isAlreadyDone ? .green : .primary)
                    if earnedPRPoints > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                            Text("\(exercisePRs.count) PR\(exercisePRs.count > 1 ? "s" : "")")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.yellow)
                    }
                }
            }

            GeometryReader { geo in
                let progress = workout.exercises.isEmpty ? 0.0 : Double(completedExercises.count) / Double(workout.exercises.count)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, 0), height: 6)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            (allCompleted || isAlreadyDone) ?
            Color.green.opacity(0.06) : Color.primary.opacity(0.04)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            (allCompleted || isAlreadyDone) ?
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 1) : nil
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    // MARK: - Why This Workout

    private var whyThisWorkoutButton: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                if showWhyWorkout {
                    showWhyWorkout = false
                } else {
                    if whyExplanation.isEmpty {
                        loadWhyExplanation()
                    }
                    showWhyWorkout = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                Text(L.t("whyThisWorkout", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if isLoadingWhy {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: showWhyWorkout ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.06), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.purple.opacity(0.1), lineWidth: 1)
            )
        }
        .sensoryFeedback(.selection, trigger: showWhyWorkout)
    }

    private var whyExplanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoadingWhy {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L.t("aiAnalyzing", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                ForEach(whyExplanation.components(separatedBy: "\n").filter { !$0.isEmpty }, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8))
                            .foregroundStyle(.purple)
                            .padding(.top, 4)
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.purple.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                removal: .opacity
            )
        )
    }

    // MARK: - Muscles Section

    private var musclesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text(L.t("musclesTargeted", lang))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(musclesTargeted, id: \.self) { muscle in
                        let isWeak = appState.profile.weakPoints.contains(where: { $0.lowercased() == muscle.lowercased() })
                        HStack(spacing: 5) {
                            if isWeak {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 5, height: 5)
                            }
                            Text(muscle)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(isWeak ? .orange : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isWeak ? Color.orange.opacity(0.1) : Color.primary.opacity(0.05))
                        .clipShape(.capsule)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Exercises

    private var exercisesList: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L.t("exercisesLabel", lang))
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(index: index, exercise: exercise)
            }
        }
    }

    private func exerciseRow(index: Int, exercise: Exercise) -> some View {
        let isCompleted = completedExercises.contains(exercise.id)
        let history = logService.history(for: exercise.name)
        let hasPR = exercisePRs.contains(exercise.id)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                if workoutStarted && !isAlreadyDone {
                    Button {
                        if !isCompleted {
                            selectedExercise = exercise
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isCompleted ? Color.green : Color.primary.opacity(0.08))
                                .frame(width: 32, height: 32)
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isCompleted)
                } else {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted, color: .secondary)

                        if hasPR {
                            HStack(spacing: 2) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 8))
                                Text("PR!")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(.capsule)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(exercise.sets) sets \u{00B7} \(exercise.reps)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(exercise.muscleGroup)
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if workoutStarted && !isAlreadyDone && !isCompleted {
                        selectedExercise = exercise
                    } else {
                        demoExercise = exercise
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if history.logs.count > 0 {
                        historyLabels(for: exercise, history: history)
                    } else {
                        Text(L.t("noDataYet", lang))
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                }

                // Info button — always accessible
                Button {
                    demoExercise = exercise
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.opacity(0.6))
                }
            }
            .padding(14)

            // Progressive overload suggestion inline
            if let suggestion = overloadSuggestion(for: history) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text(suggestion)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .padding(.top, -4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            isCompleted ? Color.green.opacity(0.04) :
            hasPR ? Color.yellow.opacity(0.04) : Color.primary.opacity(0.03)
        )
        .clipShape(.rect(cornerRadius: 14))
        .opacity(isCompleted ? 0.7 : 1)
        .animation(.spring(duration: 0.35), value: isCompleted)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isCompleted)
    }

    private func overloadSuggestion(for history: ExerciseHistory) -> String? {
        guard history.logs.count > 0, let last = history.lastSession else { return nil }
        let usesMetric = appState.profile.usesMetric
        let unit = usesMetric ? "kg" : "lbs"
        let increment = usesMetric ? 2.5 : 5.0
        let lastBest = last.bestSetWeight
        guard lastBest > 0 else { return nil }

        if history.isPRReady {
            let target = history.personalBestWeight + increment
            return "Try \(formatOverloadWeight(target))\(unit) \u{2014} you're close to a new PR!"
        }

        if history.volumeTrend == .up {
            let target = lastBest + increment
            return "Try \(formatOverloadWeight(target))\(unit) this session"
        }

        if history.volumeTrend == .neutral && history.logs.count >= 3 {
            return "Try +\(formatOverloadWeight(increment))\(unit) or +1-2 reps per set"
        }

        return nil
    }

    private func formatOverloadWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if !workoutStarted {
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        session.startWorkout(workout: workout)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text(L.t("startWorkoutBtn", lang))
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: session.isActive)
            } else if allCompleted {
                Button { completeWorkout() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        VStack(spacing: 2) {
                            Text(L.t("completeWorkoutBtn", lang))
                                .font(.headline)
                            Text("+\(workoutPoints) pts")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .opacity(0.8)
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(.rect(cornerRadius: 16))
                }
            } else if completedExercises.count > 0 {
                Button { completeWorkout() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14))
                        Text(String(format: L.t("finishEarlyFmt", lang),
                                    "\(completedExercises.count)" as NSString,
                                    "\(workout.exercises.count)" as NSString))
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 16))
                }
            } else if workoutStarted {
                Button {
                    showDiscardConfirm = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14))
                        Text(L.t("abandonWorkout", lang))
                            .font(.headline)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Already-Done Actions

    private var alreadyDoneActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text(L.t("completedToday", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Button { showEditFinished = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L.t("edit", lang))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 14))
                }

                Button { showRestartConfirm = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L.t("restart", lang))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Points Preview

    private var pointsPreview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text(L.t("competeRewards", lang))
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            HStack(spacing: 0) {
                rewardItem(icon: "checkmark.circle.fill", label: L.t("completeReward", lang), value: "+100", color: .green)
                rewardDivider
                rewardItem(icon: "list.bullet", label: L.t("perExercise", lang), value: "+10", color: .blue)
                rewardDivider
                rewardItem(icon: "trophy.fill", label: L.t("prBonus", lang), value: "+50", color: .yellow)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.04), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.yellow.opacity(0.08), lineWidth: 1)
        )
    }

    private func rewardItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var rewardDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    // MARK: - Floating Points

    private var pointsFloatView: some View {
        Text("+\(floatingPoints) pts")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(.yellow)
            .shadow(color: .yellow.opacity(0.5), radius: 8)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .offset(y: 20)),
                removal: .opacity.combined(with: .offset(y: -40))
            ))
            .padding(.top, 60)
    }

    // MARK: - Logic

    private func handleExerciseCompletion(exercise: Exercise, sets: [SetLog], hitPR: Bool) {
        let log = ExerciseLog(
            exerciseName: exercise.name,
            muscleGroup: exercise.muscleGroup,
            sets: sets,
            totalVolume: sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        )
        logService.saveLog(log)

        // Mirror per-set detail to Supabase so it survives logout/reinstall.
        // This is the fix for the "0 sets / 0 kg volume" bug — without this
        // the sets only lived in UserDefaults and got cleared on logout.
        if let userId = appState.currentUserIdPublic {
            let logCopy = log
            Task.detached {
                await SupabaseSyncService.shared.insertExerciseLog(userId: userId, log: logCopy)
            }
        }

        withAnimation(.spring(duration: 0.4)) {
            session.markExerciseCompleted(exercise.id, exerciseName: exercise.name, volume: log.computedVolume, hitPR: hitPR)
        }

        if hitPR {
            showFloatingPoints(50)
        }
    }

    private func showFloatingPoints(_ points: Int) {
        floatingPoints = points
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            showPointsFloat = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showPointsFloat = false
            }
        }
    }

    private func completeWorkout() {
        // Capture share data now while the session is intact, then enter an
        // 8-second grace period. The toast lets the user undo before any
        // history / cloud / Health writes happen.
        pendingShareData = buildShareData()
        session.beginPendingFinish()
        finishCountdown = 8

        finishTimer?.invalidate()
        finishTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if finishCountdown > 1 {
                    finishCountdown -= 1
                } else {
                    commitFinish()
                }
            }
        }
    }

    private func commitFinish() {
        finishTimer?.invalidate()
        finishTimer = nil
        guard let data = pendingShareData else {
            session.endSession()
            return
        }

        let duration = elapsedSeconds / 60
        let names = workout.exercises.filter { completedExercises.contains($0.id) }.map(\.name)
        appState.logWorkout(
            dayName: workout.name,
            exercisesCompleted: completedExercises.count,
            totalExercises: workout.exercises.count,
            durationMinutes: max(duration, 1),
            completedExerciseNames: names
        )

        if earnedPRPoints > 0 {
            appState.addBonusPoints(earnedPRPoints)
        }

        // Mirror the workout to Apple Health so the user's Activity rings update.
        HealthKitWorkoutExporter.shared.save(
            startDate: session.startTime ?? Date().addingTimeInterval(-Double(elapsedSeconds)),
            durationSeconds: max(elapsedSeconds, 60),
            exerciseCount: completedExercises.count
        )

        session.endSession()
        pendingShareData = nil
        // Defer the cover presentation by one animation cycle. Without the
        // delay, the toast dismiss (driven by isPendingFinish flipping) and
        // the fullScreenCover present run in the same SwiftUI tick, and on
        // iOS 17+ the cover gets visually swallowed — the user sees a grey
        // screen instead of the share card.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            shareData = IdentifiableShareData(data: data)
        }
    }

    private func undoFinish() {
        finishTimer?.invalidate()
        finishTimer = nil
        pendingShareData = nil
        session.cancelPendingFinish()
    }

    private func restartWorkout() {
        // Wipe today's log entries for this workout and re-enter active state.
        appState.unlogTodaysWorkout(dayLabel: workout.dayLabel, exerciseNames: workout.exercises.map(\.name))
        session.startWorkout(workout: workout)
    }

    private func loadWhyExplanation() {
        guard whyExplanation.isEmpty else { return }
        isLoadingWhy = true

        let weakPts = appState.profile.weakPoints.joined(separator: ", ")
        let goal = appState.profile.primaryGoal
        let g = appState.profile.gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"
        let nameLower = workout.name.lowercased()

        var explanation = ""
        if workout.isWeakPointFocus {
            explanation = "This workout prioritizes your weaker areas (\(weakPts.isEmpty ? "overall balance" : weakPts)) with extra volume to accelerate growth where you need it most."
        } else if nameLower.contains("glute") || nameLower.contains("hip thrust") {
            explanation = "Glute day is the cornerstone of lower-body shape. Hip thrusts, glute bridges, and Bulgarian split squats build glute fullness, lift, and separation from the hamstrings."
        } else if nameLower.contains("push") {
            explanation = isFemale
                ? "Push day strengthens shoulders, chest, and triceps for a balanced, toned upper body and stronger posture. Moderate pressing volume keeps things lean — not bulky."
                : "Push day targets chest, shoulders, and triceps. Incline movements prioritize upper chest to build your V-taper, while overhead pressing develops capped delts."
        } else if nameLower.contains("pull") {
            explanation = isFemale
                ? "Pull day strengthens your back and rear delts to lift your posture and define your shoulder line. Rows and pulldowns also tone the arms without adding bulk."
                : "Pull day develops back width and thickness. Rows build mid-back density while pulldowns create the wide lats that define an athletic physique."
        } else if nameLower.contains("leg") {
            explanation = isFemale
                ? "Leg day is the centerpiece of your training. Compound movements like squats, hip thrusts, and Romanian deadlifts build the glutes, hamstrings, and lower-body shape you're working toward."
                : "Leg day is your foundation. Compound movements like squats boost natural testosterone production and build the base that supports all other lifts."
        } else if nameLower.contains("upper") {
            explanation = isFemale
                ? "Upper body day balances pushing and pulling volume to improve posture, tone the arms, and define the shoulder line — without overdoing chest mass."
                : "Upper body day provides balanced pushing and pulling volume. This complementary approach prevents imbalances and builds a proportional physique."
        } else if nameLower.contains("lower") || nameLower.contains("core") {
            explanation = isFemale
                ? "Lower body and core work targets glutes, hamstrings, and waist definition. A strong core also tightens posture and transfers power to every other lift."
                : "Lower body and core work builds functional strength and stability. A strong core transfers power to every other lift you do."
        } else {
            explanation = "This workout is designed around your \(goal.isEmpty ? "fitness goals" : goal). The exercise selection targets \(workout.focusAreas.joined(separator: " and ")) for balanced development."
        }

        if !weakPts.isEmpty {
            explanation += "\nYour scan shows \(weakPts) as areas to focus on. This plan accounts for that with targeted exercise selection."
        }

        explanation += isFemale
            ? "\nThe rep ranges chosen build muscle tone and shape with enough volume to drive results without overtraining."
            : "\nThe rep ranges chosen optimize for hypertrophy (muscle growth) with enough volume to trigger adaptation without overtraining."

        whyExplanation = explanation
        isLoadingWhy = false
    }

    private func trendColor(_ trend: VolumeTrend) -> Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .secondary
        }
    }

    @ViewBuilder
    private func historyLabels(for exercise: Exercise, history: ExerciseHistory) -> some View {
        let mode = exercise.trackingMode
        let unit = appState.profile.usesMetric ? "kg" : "lbs"

        switch mode {
        case .timed:
            if let last = history.lastSession {
                Text("Last: \(formatDuration(last.bestSetReps))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 3) {
                Image(systemName: history.volumeTrend.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(trendColor(history.volumeTrend))
                Text("Best: \(formatDuration(history.personalBestReps))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(trendColor(history.volumeTrend))
            }
        case .repsOnly:
            if let last = history.lastSession {
                Text("Last: \(last.bestSetReps) reps")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 3) {
                Image(systemName: history.volumeTrend.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(trendColor(history.volumeTrend))
                Text("Best: \(history.personalBestReps) reps")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(trendColor(history.volumeTrend))
            }
        case .weighted, .bodyweight:
            if let last = history.lastSession {
                Text("Last: \(Int(last.bestSetWeight))\(unit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 3) {
                Image(systemName: history.volumeTrend.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(trendColor(history.volumeTrend))
                Text("Best: \(Int(history.personalBestWeight))\(unit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(trendColor(history.volumeTrend))
            }
            if history.isPRReady {
                Text(L.t("prReady", lang))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 && s == 0 { return "\(m)m" }
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return "\(s)s"
    }

    private func buildShareData() -> WorkoutShareCardData {
        let totalVolume = exerciseVolumes.values.reduce(0, +)

        var bestWeight: Double = 0
        var bestReps: Int = 0
        if let firstName = prExerciseNames.first {
            let history = ExerciseLogService.shared.history(for: firstName)
            bestWeight = history.personalBestWeight
            bestReps = history.personalBestReps
        }

        let completedExerciseList = workout.exercises.filter { completedExercises.contains($0.id) }
        let allLogs = logService.loadAll()
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayLogs = allLogs.filter { $0.date >= todayStart }

        var topExName = ""
        var topWeight: Double = 0
        var topReps: Int = 0
        for log in todayLogs {
            for s in log.sets where s.isCompleted {
                if s.weight > topWeight {
                    topWeight = s.weight
                    topReps = s.reps
                    topExName = log.exerciseName
                }
            }
        }

        // Build PR details for each PR exercise
        var prDetailsList: [PRDetail] = []
        for prName in prExerciseNames {
            // Find today's best set for this exercise
            let todayExLogs = todayLogs.filter { $0.exerciseName == prName }
            let todayBestSet = todayExLogs.flatMap(\.sets).filter(\.isCompleted).max(by: { $0.weight < $1.weight })

            // Find previous best from all logs before today
            let previousLogs = allLogs.filter { $0.exerciseName == prName && $0.date < todayStart }
            let previousBestSet = previousLogs.flatMap(\.sets).filter(\.isCompleted).max(by: { $0.weight < $1.weight })

            // Use today's best, or fall back to the exercise volume data from the session
            let newWeight = todayBestSet?.weight ?? exerciseVolumes[prName].map { _ in topWeight } ?? 0
            let newReps = todayBestSet?.reps ?? 0

            if newWeight > 0 {
                prDetailsList.append(PRDetail(
                    exerciseName: prName,
                    newWeight: newWeight,
                    newReps: newReps > 0 ? newReps : 1,
                    previousWeight: previousBestSet?.weight ?? 0,
                    previousReps: previousBestSet?.reps ?? 0
                ))
            }
        }

        let durationMin = max(elapsedSeconds / 60, 1)
        let estimatedCal = Int(Double(durationMin) * 5.5 + totalVolume * 0.015)

        return WorkoutShareCardData(
            workoutName: workout.name,
            focusAreas: workout.focusAreas,
            totalVolume: totalVolume,
            duration: durationMin,
            exercisesCompleted: completedExercises.count,
            totalExercises: workout.exercises.count,
            totalSets: completedExerciseList.reduce(0) { $0 + $1.sets },
            prCount: exercisePRs.count,
            prExerciseNames: prExerciseNames,
            pointsEarned: workoutPoints,
            prBestWeight: bestWeight,
            prBestReps: bestReps,
            weightUnit: appState.profile.usesMetric ? "kg" : "lbs",
            topSetExercise: topExName,
            topSetWeight: topWeight,
            topSetReps: topReps,
            estimatedCalories: estimatedCal,
            exercises: completedExerciseList,
            workoutDate: Date(),
            prDetails: prDetailsList
        )
    }
}

struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        Task { @MainActor in
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
