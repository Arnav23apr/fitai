import SwiftUI

struct PlanView: View {
    @Environment(AppState.self) private var appState
    @State private var showCoach: Bool = false
    @State private var selectedDay: WorkoutDay? = nil

    private var workoutPlan: [WorkoutDay] {
        generatePersonalizedPlan()
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if appState.profile.latestScore != nil {
                        scanInsightCard
                    } else {
                        promptScanCard
                    }

                    if appState.profile.latestScore != nil && !appState.profile.weakPoints.isEmpty {
                        focusAreasSection
                    }

                    weeklyProgressBar

                    coachCard

                    weeklyPlanSection

                    todaysWorkoutDetail
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color.black)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showCoach) {
                CoachView()
            }
            .sheet(item: $selectedDay) { day in
                WorkoutDetailSheet(workout: day)
            }
        }
    }

    private var scanInsightCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text("Scan Insight")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Text("Your plan targets weak areas identified in your latest scan.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", appState.profile.latestScore ?? 0))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            if !appState.profile.strongPoints.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.7))
                    Text("Strong: \(appState.profile.strongPoints.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.green.opacity(0.1), lineWidth: 1)
        )
    }

    private var promptScanCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.2))

            VStack(spacing: 4) {
                Text("Scan to Personalize")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Complete a body scan to get a workout plan\ntailored to your weak points")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text("Focus Areas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.profile.weakPoints, id: \.self) { point in
                        focusAreaCard(point)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func focusAreaCard(_ area: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: muscleGroupIcon(area))
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(area)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func muscleGroupIcon(_ area: String) -> String {
        let lower = area.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("shoulder") || lower.contains("delt") { return "figure.boxing" }
        if lower.contains("back") || lower.contains("lat") { return "figure.rowing" }
        if lower.contains("arm") || lower.contains("bicep") || lower.contains("tricep") { return "figure.arms.open" }
        if lower.contains("leg") || lower.contains("quad") || lower.contains("hamstring") || lower.contains("calf") || lower.contains("calves") { return "figure.run" }
        if lower.contains("glute") { return "figure.stairs" }
        if lower.contains("core") || lower.contains("ab") { return "figure.core.training" }
        if lower.contains("body fat") || lower.contains("fat") { return "flame.fill" }
        if lower.contains("definition") || lower.contains("muscle") { return "figure.highintensity.intervaltraining" }
        return "figure.mixed.cardio"
    }

    private var weeklyProgressBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Weekly Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(appState.workoutsThisWeek)/\(appState.profile.workoutsPerWeek)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            }

            GeometryReader { geo in
                let progress = min(Double(appState.workoutsThisWeek) / max(Double(appState.profile.workoutsPerWeek), 1), 1.0)
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
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                    let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                    let shortLabels = ["M", "T", "W", "T", "F", "S", "S"]
                    let idx = shortLabels.firstIndex(of: label) ?? 0
                    let dayLabel = dayLabels[idx]
                    let completed = appState.isDayCompleted(dayLabel)
                    Circle()
                        .fill(completed ? Color.green : Color.white.opacity(0.1))
                        .frame(width: 8, height: 8)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var coachCard: some View {
        Button(action: { showCoach = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Coach")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Ask anything about fitness, nutrition, or your plan")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.06)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .sensoryFeedback(.selection, trigger: showCoach)
    }

    private var weeklyPlanSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(appState.profile.workoutsPerWeek)x/week")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(.capsule)
            }

            ForEach(Array(workoutPlan.enumerated()), id: \.element.id) { index, workout in
                Button(action: {
                    if !workout.isRestDay {
                        selectedDay = workout
                    }
                }) {
                    workoutRow(workout, isToday: index == todayIndex)
                }
                .disabled(workout.isRestDay)
                .sensoryFeedback(.selection, trigger: selectedDay?.id)
            }
        }
    }

    private func workoutRow(_ workout: WorkoutDay, isToday: Bool) -> some View {
        let completed = appState.isDayCompleted(workout.dayLabel)
        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(workout.dayLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isToday ? .white : .white.opacity(0.35))
                if isToday {
                    Circle()
                        .fill(.green)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 32)

            ZStack {
                Image(systemName: workout.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(
                        completed ? .green :
                        workout.isRestDay ? .white.opacity(0.2) :
                        workout.isWeakPointFocus ? .orange : .white.opacity(0.6)
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        completed ? Color.green.opacity(0.12) :
                        workout.isWeakPointFocus ?
                        Color.orange.opacity(0.1) : Color.white.opacity(0.06)
                    )
                    .clipShape(Circle())

                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .background(Circle().fill(.black).frame(width: 12, height: 12))
                        .offset(x: 14, y: 14)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(workout.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            completed ? .white.opacity(0.5) :
                            workout.isRestDay ? .white.opacity(0.3) : .white
                        )
                    if completed {
                        Text("DONE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(.capsule)
                    } else if workout.isWeakPointFocus {
                        Text("FOCUS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(.capsule)
                    }
                }
                Text(workout.focusAreas.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer()

            if !workout.isRestDay {
                Text("\(workout.exercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
        .padding(13)
        .background(
            completed ? Color.green.opacity(0.04) :
            isToday ? Color.white.opacity(0.07) : Color.white.opacity(0.04)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            isToday && !completed ?
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1) : nil
        )
    }

    private var todaysWorkoutDetail: some View {
        Group {
            let todayWorkout = workoutPlan[safe: todayIndex]
            if let workout = todayWorkout, !workout.isRestDay {
                VStack(spacing: 14) {
                    HStack {
                        Text("Today's Exercises")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button(action: {
                            selectedDay = workout
                        }) {
                            Text(appState.isDayCompleted(workout.dayLabel) ? "Review" : "Start")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.12))
                                .clipShape(.capsule)
                        }
                    }

                    ForEach(workout.exercises.prefix(4)) { exercise in
                        HStack(spacing: 14) {
                            Image(systemName: exerciseIcon(exercise.muscleGroup))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.06))
                                .clipShape(.rect(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text("\(exercise.sets) sets · \(exercise.reps) reps")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.3))
                            }

                            Spacer()

                            Text(exercise.muscleGroup)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.vertical, 4)
                    }

                    if workout.exercises.count > 4 {
                        Text("+\(workout.exercises.count - 4) more exercises")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .clipShape(.rect(cornerRadius: 16))
            }
        }
    }

    private func exerciseIcon(_ muscleGroup: String) -> String {
        let lower = muscleGroup.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("shoulder") || lower.contains("delt") { return "figure.boxing" }
        if lower.contains("back") || lower.contains("lat") { return "figure.rowing" }
        if lower.contains("bicep") || lower.contains("curl") { return "figure.arms.open" }
        if lower.contains("tricep") { return "figure.arms.open" }
        if lower.contains("quad") || lower.contains("leg") { return "figure.run" }
        if lower.contains("hamstring") { return "figure.run" }
        if lower.contains("glute") { return "figure.stairs" }
        if lower.contains("calf") || lower.contains("calves") { return "figure.run" }
        if lower.contains("core") || lower.contains("ab") || lower.contains("oblique") { return "figure.core.training" }
        if lower.contains("cardio") { return "figure.run" }
        if lower.contains("hip") { return "figure.flexibility" }
        if lower.contains("spine") { return "figure.mind.and.body" }
        if lower.contains("full body") { return "figure.mixed.cardio" }
        return "dumbbell.fill"
    }

    private func generatePersonalizedPlan() -> [WorkoutDay] {
        let weakPoints = appState.profile.weakPoints
        let location = appState.profile.trainingLocation
        let perWeek = appState.profile.workoutsPerWeek

        let hasWeakPoints = !weakPoints.isEmpty
        let isGym = location.lowercased().contains("gym")

        let weakLower = weakPoints.contains(where: { ["Legs", "Glutes", "Calves"].contains($0) })
        let weakUpper = weakPoints.contains(where: { ["Chest", "Back", "Shoulders", "Arms"].contains($0) })
        let weakCore = weakPoints.contains(where: { ["Core", "Abs"].contains($0) })

        var days: [WorkoutDay] = []

        let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

        if perWeek >= 5 {
            days = [
                buildPushDay(isGym: isGym, weakFocus: weakPoints.contains("Shoulders") || weakPoints.contains("Chest")),
                buildPullDay(isGym: isGym, weakFocus: weakPoints.contains("Back")),
                buildLegDay(isGym: isGym, weakFocus: weakLower),
                buildUpperDay(isGym: isGym, weakFocus: weakUpper),
                buildLowerCorDay(isGym: isGym, weakFocus: weakLower || weakCore),
                WorkoutDay(dayLabel: "SAT", name: "Active Recovery", focusAreas: ["Mobility", "Light Cardio"], icon: "figure.cooldown", isRestDay: false, exercises: recoveryExercises()),
                WorkoutDay(dayLabel: "SUN", name: "Rest", focusAreas: ["Full Recovery"], icon: "bed.double.fill", isRestDay: true),
            ]
        } else if perWeek >= 3 {
            days = [
                buildPushDay(isGym: isGym, weakFocus: weakUpper),
                WorkoutDay(dayLabel: "TUE", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                buildPullDay(isGym: isGym, weakFocus: weakPoints.contains("Back")),
                WorkoutDay(dayLabel: "THU", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                buildLegDay(isGym: isGym, weakFocus: weakLower),
                hasWeakPoints ?
                    buildWeakPointDay(weakPoints: weakPoints, isGym: isGym) :
                    WorkoutDay(dayLabel: "SAT", name: "Active Recovery", focusAreas: ["Mobility"], icon: "figure.cooldown", isRestDay: false, exercises: recoveryExercises()),
                WorkoutDay(dayLabel: "SUN", name: "Rest", focusAreas: ["Full Recovery"], icon: "bed.double.fill", isRestDay: true),
            ]
        } else {
            days = [
                buildFullBodyDay(isGym: isGym, weakFocus: hasWeakPoints, label: "MON"),
                WorkoutDay(dayLabel: "TUE", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                WorkoutDay(dayLabel: "WED", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                buildFullBodyDay(isGym: isGym, weakFocus: hasWeakPoints, label: "THU"),
                WorkoutDay(dayLabel: "FRI", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                WorkoutDay(dayLabel: "SAT", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                WorkoutDay(dayLabel: "SUN", name: "Rest", focusAreas: ["Full Recovery"], icon: "bed.double.fill", isRestDay: true),
            ]
        }

        for i in 0..<days.count {
            days[i] = WorkoutDay(
                id: days[i].id,
                dayLabel: dayLabels[i],
                name: days[i].name,
                focusAreas: days[i].focusAreas,
                icon: days[i].icon,
                isRestDay: days[i].isRestDay,
                exercises: days[i].exercises,
                isWeakPointFocus: days[i].isWeakPointFocus
            )
        }

        return days
    }

    private func buildPushDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Barbell Bench Press", sets: 4, reps: "8-10", muscleGroup: "Chest"),
            Exercise(name: "Incline Dumbbell Press", sets: 3, reps: "10-12", muscleGroup: "Upper Chest"),
            Exercise(name: "Overhead Press", sets: 4, reps: "8-10", muscleGroup: "Shoulders"),
            Exercise(name: "Lateral Raises", sets: 3, reps: "12-15", muscleGroup: "Side Delts"),
            Exercise(name: "Cable Flyes", sets: 3, reps: "12-15", muscleGroup: "Chest"),
            Exercise(name: "Tricep Pushdowns", sets: 3, reps: "12-15", muscleGroup: "Triceps"),
        ] : [
            Exercise(name: "Push-Ups", sets: 4, reps: "15-20", muscleGroup: "Chest"),
            Exercise(name: "Pike Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Diamond Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
            Exercise(name: "Dips (Chair)", sets: 3, reps: "12-15", muscleGroup: "Chest/Triceps"),
            Exercise(name: "Decline Push-Ups", sets: 3, reps: "12-15", muscleGroup: "Upper Chest"),
        ]
        return WorkoutDay(dayLabel: "MON", name: "Push Day", focusAreas: ["Chest", "Shoulders", "Triceps"], icon: "figure.strengthtraining.traditional", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildPullDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Barbell Rows", sets: 4, reps: "8-10", muscleGroup: "Back"),
            Exercise(name: "Lat Pulldown", sets: 3, reps: "10-12", muscleGroup: "Lats"),
            Exercise(name: "Face Pulls", sets: 3, reps: "15-20", muscleGroup: "Rear Delts"),
            Exercise(name: "Seated Cable Row", sets: 3, reps: "10-12", muscleGroup: "Mid Back"),
            Exercise(name: "Barbell Curls", sets: 3, reps: "10-12", muscleGroup: "Biceps"),
            Exercise(name: "Hammer Curls", sets: 3, reps: "12-15", muscleGroup: "Biceps"),
        ] : [
            Exercise(name: "Pull-Ups", sets: 4, reps: "6-10", muscleGroup: "Back"),
            Exercise(name: "Inverted Rows", sets: 3, reps: "10-12", muscleGroup: "Mid Back"),
            Exercise(name: "Superman Hold", sets: 3, reps: "30s", muscleGroup: "Lower Back"),
            Exercise(name: "Band Face Pulls", sets: 3, reps: "15-20", muscleGroup: "Rear Delts"),
            Exercise(name: "Doorway Curls", sets: 3, reps: "12-15", muscleGroup: "Biceps"),
        ]
        return WorkoutDay(dayLabel: "TUE", name: "Pull Day", focusAreas: ["Back", "Biceps", "Rear Delts"], icon: "figure.rowing", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildLegDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Barbell Squat", sets: 4, reps: "8-10", muscleGroup: "Quads"),
            Exercise(name: "Romanian Deadlift", sets: 4, reps: "8-10", muscleGroup: "Hamstrings"),
            Exercise(name: "Leg Press", sets: 3, reps: "10-12", muscleGroup: "Quads"),
            Exercise(name: "Walking Lunges", sets: 3, reps: "12/leg", muscleGroup: "Glutes"),
            Exercise(name: "Calf Raises", sets: 4, reps: "15-20", muscleGroup: "Calves"),
            Exercise(name: "Leg Curl", sets: 3, reps: "12-15", muscleGroup: "Hamstrings"),
        ] : [
            Exercise(name: "Bulgarian Split Squats", sets: 4, reps: "10/leg", muscleGroup: "Quads"),
            Exercise(name: "Glute Bridges", sets: 4, reps: "15-20", muscleGroup: "Glutes"),
            Exercise(name: "Jump Squats", sets: 3, reps: "12-15", muscleGroup: "Quads"),
            Exercise(name: "Single Leg RDL", sets: 3, reps: "10/leg", muscleGroup: "Hamstrings"),
            Exercise(name: "Wall Sit", sets: 3, reps: "45s", muscleGroup: "Quads"),
        ]
        return WorkoutDay(dayLabel: "WED", name: "Legs", focusAreas: ["Quads", "Hamstrings", "Glutes"], icon: "figure.run", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildUpperDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Dumbbell Bench Press", sets: 3, reps: "10-12", muscleGroup: "Chest"),
            Exercise(name: "Cable Rows", sets: 3, reps: "10-12", muscleGroup: "Back"),
            Exercise(name: "Arnold Press", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Incline Curls", sets: 3, reps: "12-15", muscleGroup: "Biceps"),
            Exercise(name: "Overhead Tricep Extension", sets: 3, reps: "12-15", muscleGroup: "Triceps"),
        ] : [
            Exercise(name: "Push-Ups", sets: 3, reps: "15-20", muscleGroup: "Chest"),
            Exercise(name: "Inverted Rows", sets: 3, reps: "10-12", muscleGroup: "Back"),
            Exercise(name: "Pike Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Chin-Ups", sets: 3, reps: "6-10", muscleGroup: "Biceps"),
            Exercise(name: "Diamond Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
        ]
        return WorkoutDay(dayLabel: "THU", name: "Upper Body", focusAreas: ["Chest", "Back", "Arms"], icon: "figure.mixed.cardio", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildLowerCorDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Front Squats", sets: 4, reps: "8-10", muscleGroup: "Quads"),
            Exercise(name: "Hip Thrusts", sets: 4, reps: "10-12", muscleGroup: "Glutes"),
            Exercise(name: "Leg Extensions", sets: 3, reps: "12-15", muscleGroup: "Quads"),
            Exercise(name: "Hanging Leg Raises", sets: 3, reps: "12-15", muscleGroup: "Core"),
            Exercise(name: "Cable Woodchops", sets: 3, reps: "12/side", muscleGroup: "Obliques"),
        ] : [
            Exercise(name: "Pistol Squat Progression", sets: 3, reps: "8/leg", muscleGroup: "Quads"),
            Exercise(name: "Single Leg Glute Bridge", sets: 3, reps: "12/leg", muscleGroup: "Glutes"),
            Exercise(name: "Plank", sets: 3, reps: "60s", muscleGroup: "Core"),
            Exercise(name: "Bicycle Crunches", sets: 3, reps: "20", muscleGroup: "Obliques"),
            Exercise(name: "Mountain Climbers", sets: 3, reps: "30s", muscleGroup: "Core"),
        ]
        return WorkoutDay(dayLabel: "FRI", name: "Lower + Core", focusAreas: ["Legs", "Glutes", "Core"], icon: "figure.core.training", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildWeakPointDay(weakPoints: [String], isGym: Bool) -> WorkoutDay {
        var exercises: [Exercise] = []
        for point in weakPoints.prefix(3) {
            switch point {
            case "Shoulders":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Overhead Press" : "Pike Push-Ups", sets: 4, reps: "10-12", muscleGroup: "Shoulders"),
                    Exercise(name: "Lateral Raises", sets: 4, reps: "15-20", muscleGroup: "Side Delts"),
                ])
            case "Chest":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Incline Bench Press" : "Decline Push-Ups", sets: 4, reps: "10-12", muscleGroup: "Chest"),
                    Exercise(name: isGym ? "Cable Crossovers" : "Wide Push-Ups", sets: 3, reps: "12-15", muscleGroup: "Chest"),
                ])
            case "Back":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "T-Bar Row" : "Inverted Rows", sets: 4, reps: "10-12", muscleGroup: "Back"),
                    Exercise(name: isGym ? "Straight Arm Pulldown" : "Superman Hold", sets: 3, reps: isGym ? "12-15" : "30s", muscleGroup: "Back"),
                ])
            case "Legs", "Glutes", "Calves":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Hack Squat" : "Pistol Squats", sets: 4, reps: "10-12", muscleGroup: "Quads"),
                    Exercise(name: isGym ? "Seated Calf Raise" : "Single Leg Calf Raise", sets: 4, reps: "15-20", muscleGroup: "Calves"),
                ])
            case "Arms":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Preacher Curls" : "Chin-Ups", sets: 3, reps: "10-12", muscleGroup: "Biceps"),
                    Exercise(name: isGym ? "Skull Crushers" : "Diamond Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
                ])
            case "Core", "Abs":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Cable Crunches" : "Hanging Knee Raises", sets: 3, reps: "15-20", muscleGroup: "Core"),
                    Exercise(name: "Plank", sets: 3, reps: "60s", muscleGroup: "Core"),
                ])
            default:
                exercises.append(Exercise(name: "Extra Volume Work", sets: 3, reps: "12-15", muscleGroup: point))
            }
        }
        return WorkoutDay(dayLabel: "SAT", name: "Weak Point Focus", focusAreas: weakPoints, icon: "target", isRestDay: false, exercises: exercises, isWeakPointFocus: true)
    }

    private func buildFullBodyDay(isGym: Bool, weakFocus: Bool, label: String) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Squat", sets: 3, reps: "8-10", muscleGroup: "Legs"),
            Exercise(name: "Bench Press", sets: 3, reps: "8-10", muscleGroup: "Chest"),
            Exercise(name: "Barbell Row", sets: 3, reps: "8-10", muscleGroup: "Back"),
            Exercise(name: "Overhead Press", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Plank", sets: 3, reps: "45s", muscleGroup: "Core"),
        ] : [
            Exercise(name: "Bodyweight Squat", sets: 3, reps: "15-20", muscleGroup: "Legs"),
            Exercise(name: "Push-Ups", sets: 3, reps: "15-20", muscleGroup: "Chest"),
            Exercise(name: "Inverted Rows", sets: 3, reps: "10-12", muscleGroup: "Back"),
            Exercise(name: "Pike Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Plank", sets: 3, reps: "45s", muscleGroup: "Core"),
        ]
        return WorkoutDay(dayLabel: label, name: "Full Body", focusAreas: ["Total Body"], icon: "figure.strengthtraining.traditional", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func recoveryExercises() -> [Exercise] {
        [
            Exercise(name: "Foam Rolling", sets: 1, reps: "10min", muscleGroup: "Full Body"),
            Exercise(name: "Hip Flexor Stretch", sets: 2, reps: "60s/side", muscleGroup: "Hips"),
            Exercise(name: "Cat-Cow Stretch", sets: 2, reps: "10", muscleGroup: "Spine"),
            Exercise(name: "Light Walk", sets: 1, reps: "20min", muscleGroup: "Cardio"),
        ]
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
