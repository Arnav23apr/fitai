import SwiftUI

struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let workout: WorkoutDay
    @State private var completedExercises: Set<String> = []
    @State private var workoutStarted: Bool = false
    @State private var startTime: Date? = nil
    @State private var showCompletionAlert: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var selectedExercise: Exercise? = nil
    @State private var showWhyWorkout: Bool = false
    @State private var whyExplanation: String = ""
    @State private var isLoadingWhy: Bool = false
    @State private var earnedPRPoints: Int = 0
    @State private var exercisePRs: Set<String> = []
    @State private var showPointsFloat: Bool = false
    @State private var floatingPoints: Int = 0
    @State private var completionAnimating: Bool = false
    @State private var showShareCard: Bool = false
    @State private var exerciseVolumes: [String: Double] = [:]
    @State private var prExerciseNames: [String] = []

    private let logService = ExerciseLogService.shared

    private var allCompleted: Bool {
        completedExercises.count == workout.exercises.count
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

                    musclesSection

                    exercisesList

                    if !workout.isRestDay && !isAlreadyDone {
                        actionButton
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
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                SetLoggingSheet(exercise: exercise) { completedSets, hitPR in
                    handleExerciseCompletion(exercise: exercise, sets: completedSets, hitPR: hitPR)
                }
            }
            .sensoryFeedback(.success, trigger: showShareCard)
        }
        .overlay(alignment: .top) {
            if showPointsFloat {
                pointsFloatView
            }
        }
        .fullScreenCover(isPresented: $showShareCard) {
            WorkoutShareOverlay(
                data: buildShareData(),
                onDismiss: {
                    showShareCard = false
                    dismiss()
                }
            )
            .background(ClearBackground())
        }
        .onDisappear { timer?.invalidate() }
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
                            Text("FOCUS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(.capsule)
                        }
                        if isAlreadyDone {
                            Text("DONE")
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
                miniStat(value: "\(workout.exercises.count)", label: "Exercises", icon: "list.bullet", color: .blue)
                miniDivider
                miniStat(value: "\(totalSets)", label: "Total Sets", icon: "square.stack.fill", color: .purple)
                miniDivider
                miniStat(value: estimatedTime, label: "Est. Time", icon: "clock.fill", color: .green)
                miniDivider
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < difficultyLevel ? "flame.fill" : "flame")
                                .font(.system(size: 8))
                                .foregroundStyle(i < difficultyLevel ? .orange : Color(.quaternaryLabel))
                        }
                    }
                    Text("Difficulty")
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
            return "Chest priority day — emphasize upper chest for V-taper development"
        }
        if workout.name.lowercased().contains("pull") {
            return "Back width focus — lat pulldowns and rows build your V-taper"
        }
        if workout.name.lowercased().contains("leg") {
            return "Foundation day — compound leg movements boost testosterone"
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
                    Text(isAlreadyDone ? "Completed" : "In Progress")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isAlreadyDone ? .green : .primary)
                    if workoutStarted && !isAlreadyDone {
                        Text(formatTime(elapsedSeconds))
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
            withAnimation(.spring(duration: 0.4)) {
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
                Text("Why This Workout?")
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
                    Text("AI is analyzing your workout...")
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
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Muscles Section

    private var musclesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("Muscles Targeted")
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
                Text("Exercises")
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

        return Button {
            if workoutStarted && !isAlreadyDone && !isCompleted {
                selectedExercise = exercise
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    if workoutStarted && !isAlreadyDone {
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
                            Text("\(exercise.sets) sets · \(exercise.reps)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(exercise.muscleGroup)
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if history.logs.count > 0 {
                            if let last = history.lastSession {
                                HStack(spacing: 3) {
                                    Text("Last: \(Int(last.bestSetWeight))kg")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 3) {
                                Image(systemName: history.volumeTrend.icon)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(trendColor(history.volumeTrend))
                                Text("Best: \(Int(history.personalBestWeight))kg")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(trendColor(history.volumeTrend))
                            }

                            if history.isPRReady {
                                Text("PR Ready")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(.capsule)
                            }
                        } else {
                            Text("No data yet")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }
                .padding(14)
            }
            .background(
                isCompleted ? Color.green.opacity(0.04) :
                hasPR ? Color.yellow.opacity(0.04) : Color.primary.opacity(0.03)
            )
            .clipShape(.rect(cornerRadius: 14))
            .opacity(isCompleted ? 0.7 : 1)
            .animation(.spring(duration: 0.35), value: isCompleted)
        }
        .disabled(!workoutStarted || isAlreadyDone || isCompleted)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isCompleted)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if !workoutStarted {
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        workoutStarted = true
                        startTime = Date()
                        startTimer()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Start Workout")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: workoutStarted)
            } else if allCompleted {
                Button { completeWorkout() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        VStack(spacing: 2) {
                            Text("Complete Workout")
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
                        Text("Finish Early (\(completedExercises.count)/\(workout.exercises.count))")
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 16))
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
                Text("Compete Rewards")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            HStack(spacing: 0) {
                rewardItem(icon: "checkmark.circle.fill", label: "Complete", value: "+100", color: .green)
                rewardDivider
                rewardItem(icon: "list.bullet", label: "Per Exercise", value: "+10", color: .blue)
                rewardDivider
                rewardItem(icon: "trophy.fill", label: "PR Bonus", value: "+50", color: .yellow)
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
        _ = withAnimation(.spring(duration: 0.4)) {
            completedExercises.insert(exercise.id)
        }

        let log = ExerciseLog(
            exerciseName: exercise.name,
            muscleGroup: exercise.muscleGroup,
            sets: sets,
            totalVolume: sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        )
        logService.saveLog(log)

        exerciseVolumes[exercise.id] = log.computedVolume

        if hitPR {
            earnedPRPoints += 50
            exercisePRs.insert(exercise.id)
            prExerciseNames.append(exercise.name)
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
        timer?.invalidate()
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

        showShareCard = true
    }

    private func loadWhyExplanation() {
        guard whyExplanation.isEmpty else { return }
        isLoadingWhy = true

        let weakPts = appState.profile.weakPoints.joined(separator: ", ")
        let goal = appState.profile.primaryGoal

        var explanation = ""
        if workout.isWeakPointFocus {
            explanation = "This workout prioritizes your weaker areas (\(weakPts.isEmpty ? "overall balance" : weakPts)) with extra volume to accelerate growth where you need it most."
        } else if workout.name.lowercased().contains("push") {
            explanation = "Push day targets chest, shoulders, and triceps. Incline movements prioritize upper chest to build your V-taper, while overhead pressing develops capped delts."
        } else if workout.name.lowercased().contains("pull") {
            explanation = "Pull day develops back width and thickness. Rows build mid-back density while pulldowns create the wide lats that define an athletic physique."
        } else if workout.name.lowercased().contains("leg") {
            explanation = "Leg day is your foundation. Compound movements like squats boost natural testosterone production and build the base that supports all other lifts."
        } else if workout.name.lowercased().contains("upper") {
            explanation = "Upper body day provides balanced pushing and pulling volume. This complementary approach prevents imbalances and builds a proportional physique."
        } else if workout.name.lowercased().contains("lower") || workout.name.lowercased().contains("core") {
            explanation = "Lower body and core work builds functional strength and stability. A strong core transfers power to every other lift you do."
        } else {
            explanation = "This workout is designed around your \(goal.isEmpty ? "fitness goals" : goal). The exercise selection targets \(workout.focusAreas.joined(separator: " and ")) for balanced development."
        }

        if !weakPts.isEmpty {
            explanation += "\nYour scan shows \(weakPts) as areas to focus on — this plan accounts for that with targeted exercise selection."
        }

        explanation += "\nThe rep ranges chosen optimize for hypertrophy (muscle growth) with enough volume to trigger adaptation without overtraining."

        whyExplanation = explanation
        isLoadingWhy = false
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if let start = startTime {
                    elapsedSeconds = Int(Date().timeIntervalSince(start))
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func trendColor(_ trend: VolumeTrend) -> Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .secondary
        }
    }

    private func buildShareData() -> WorkoutShareCardData {
        let totalVolume = exerciseVolumes.values.reduce(0, +)
        let completedNames = workout.exercises.filter { completedExercises.contains($0.id) }.map(\.name)

        var bestWeight: Double = 0
        var bestReps: Int = 0
        if let firstName = prExerciseNames.first {
            let history = ExerciseLogService.shared.history(for: firstName)
            bestWeight = history.personalBestWeight
            bestReps = history.personalBestReps
        }

        return WorkoutShareCardData(
            workoutName: workout.name,
            focusAreas: workout.focusAreas,
            totalVolume: totalVolume,
            duration: max(elapsedSeconds / 60, 1),
            exercisesCompleted: completedExercises.count,
            totalExercises: workout.exercises.count,
            totalSets: workout.exercises.filter { completedExercises.contains($0.id) }.reduce(0) { $0 + $1.sets },
            prCount: exercisePRs.count,
            prExerciseNames: prExerciseNames,
            pointsEarned: workoutPoints,
            prBestWeight: bestWeight,
            prBestReps: bestReps
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
