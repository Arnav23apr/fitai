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

    private var allCompleted: Bool {
        completedExercises.count == workout.exercises.count
    }

    private var isAlreadyDone: Bool {
        appState.isDayCompleted(workout.dayLabel)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerCard

                    if workoutStarted || isAlreadyDone {
                        progressCard
                    }

                    exercisesList

                    if !workout.isRestDay && !isAlreadyDone {
                        actionButton
                    }

                    tipsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.black)
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .alert("Workout Complete!", isPresented: $showCompletionAlert) {
                Button("Finish") {
                    dismiss()
                }
            } message: {
                let mins = elapsedSeconds / 60
                Text("You completed \(completedExercises.count)/\(workout.exercises.count) exercises in \(mins) minutes. +\(100 + completedExercises.count * 10) points!")
            }
            .sensoryFeedback(.success, trigger: showCompletionAlert)
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: workout.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(workout.isWeakPointFocus ? .orange : .white)
                    .frame(width: 52, height: 52)
                    .background(
                        workout.isWeakPointFocus ?
                        Color.orange.opacity(0.12) : Color.white.opacity(0.08)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        if workout.isWeakPointFocus {
                            Text("FOCUS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(.capsule)
                        }
                        if isAlreadyDone {
                            Text("DONE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .clipShape(.capsule)
                        }
                    }
                    Text(workout.focusAreas.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
            }

            HStack(spacing: 0) {
                miniStat(value: "\(workout.exercises.count)", label: "Exercises")
                miniDivider
                miniStat(value: "\(totalSets)", label: "Total Sets")
                miniDivider
                miniStat(value: estimatedTime, label: "Est. Time")
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAlreadyDone ? "Completed" : "In Progress")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isAlreadyDone ? .green : .white)
                    if workoutStarted && !isAlreadyDone {
                        Text(formatTime(elapsedSeconds))
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()
                Text("\(completedExercises.count)/\(workout.exercises.count)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(allCompleted || isAlreadyDone ? .green : .white)
            }

            GeometryReader { geo in
                let progress = workout.exercises.isEmpty ? 0.0 : Double(completedExercises.count) / Double(workout.exercises.count)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
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
            Color.green.opacity(0.06) : Color.white.opacity(0.04)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            (allCompleted || isAlreadyDone) ?
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 1) : nil
        )
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets }
    }

    private var estimatedTime: String {
        let minutes = totalSets * 3
        return "\(minutes)min"
    }

    private var exercisesList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Exercises")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                let isCompleted = completedExercises.contains(exercise.id)
                HStack(spacing: 14) {
                    if workoutStarted && !isAlreadyDone {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                if isCompleted {
                                    completedExercises.remove(exercise.id)
                                } else {
                                    completedExercises.insert(exercise.id)
                                }
                            }
                        }) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isCompleted ? .green : .white.opacity(0.2))
                        }
                    } else {
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isCompleted ? .white.opacity(0.4) : .white)
                            .strikethrough(isCompleted, color: .white.opacity(0.3))
                        Text(exercise.muscleGroup)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(exercise.sets) sets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(isCompleted ? 0.3 : 0.6))
                        Text(exercise.reps)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(isCompleted ? 0.15 : 0.3))
                    }
                }
                .padding(14)
                .background(isCompleted ? Color.green.opacity(0.04) : Color.white.opacity(0.04))
                .clipShape(.rect(cornerRadius: 14))
                .sensoryFeedback(.impact(flexibility: .soft), trigger: isCompleted)
            }
        }
    }

    private var actionButton: some View {
        Group {
            if !workoutStarted {
                Button(action: {
                    withAnimation(.spring(duration: 0.4)) {
                        workoutStarted = true
                        startTime = Date()
                        startTimer()
                    }
                }) {
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
                Button(action: {
                    completeWorkout()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Complete Workout")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(.rect(cornerRadius: 16))
                }
            } else {
                Button(action: {
                    completeWorkout()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14))
                        Text("Finish Early (\(completedExercises.count)/\(workout.exercises.count))")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 16))
                }
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow.opacity(0.7))
                Text("Tips")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                tipRow("Rest 60-90s between sets for hypertrophy")
                tipRow("Focus on controlled eccentric (lowering) phase")
                tipRow("Stay hydrated — aim for water between sets")
                if workout.isWeakPointFocus {
                    tipRow("Extra volume on weak points accelerates growth")
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
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
        showCompletionAlert = true
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
}
