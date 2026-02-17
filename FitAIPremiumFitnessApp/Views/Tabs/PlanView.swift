import SwiftUI

struct PlanView: View {
    @Environment(AppState.self) private var appState

    private var lang: String { appState.profile.selectedLanguage }
    @State private var showCoach: Bool = false
    @State private var selectedDay: WorkoutDay? = nil
    @State private var selectedFocusItem: FocusAreaItem? = nil
    @State private var appeared: Bool = false
    @State private var coachQuestionSent: String? = nil

    private var workoutPlan: [WorkoutDay] {
        generatePersonalizedPlan()
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var todayWorkout: WorkoutDay? {
        workoutPlan[safe: todayIndex]
    }

    private var completedCount: Int {
        appState.workoutsThisWeek
    }

    private var weeklyXP: Int {
        appState.profile.workoutLogs
            .filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
            }
            .reduce(0) { $0 + 100 + ($1.exercisesCompleted * 10) }
    }

    private var nextTierPoints: Int {
        let pts = appState.profile.points
        if pts < 500 { return 500 }
        if pts < 2000 { return 2000 }
        if pts < 5000 { return 5000 }
        if pts < 10000 { return 10000 }
        return pts
    }

    private var nextTierName: String {
        let pts = appState.profile.points
        if pts < 500 { return "Silver" }
        if pts < 2000 { return "Gold" }
        if pts < 5000 { return "Platinum" }
        if pts < 10000 { return "Diamond" }
        return "Diamond"
    }

    private var daysSinceLastScan: Int? {
        guard let lastScan = appState.profile.lastScanDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastScan, to: Date()).day
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    planSummaryCard
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    todayGoalHero
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    weeklyStreakSection

                    if appState.profile.latestScore != nil {
                        scanInsightCard
                    } else {
                        promptScanCard
                    }

                    if appState.profile.latestScore != nil && !appState.profile.weakPoints.isEmpty {
                        focusAreasSection
                    }

                    competeIntegrationCard

                    weeklyPlanSection

                    nextScanReminderCard

                    weeklySummaryCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
                .opacity(appeared ? 1 : 0)
            }
            .background(Color(.systemBackground))
            .overlay(alignment: .bottomTrailing) {
                aiFloatingButton
            }
            .navigationTitle(L.t("plan", lang))
            .navigationBarTitleDisplayMode(.large)
                        .sheet(isPresented: $showCoach) {
                CoachView()
            }
            .sheet(item: $selectedDay) { day in
                WorkoutDetailSheet(workout: day)
            }
            .sheet(item: $selectedFocusItem) { item in
                FocusAreaDetailSheet(
                    area: item.area,
                    priority: focusAreaPriority(item.area),
                    score: focusAreaScore(item.area),
                    exercises: focusAreaExercises(item.area)
                )
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Plan Builder Summary

    private var planSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text(L.t("yourPlanBasedOn", lang))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            let items = planBasisItems
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(item.color)
                            .frame(width: 20)
                        Text(item.text)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.cyan.opacity(0.05), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.cyan.opacity(0.08), lineWidth: 1)
        )
    }

    private var planBasisItems: [(icon: String, text: String, color: Color)] {
        var items: [(icon: String, text: String, color: Color)] = []
        if let score = appState.profile.latestScore {
            items.append(("chart.bar.fill", "Score: \(String(format: "%.1f", score))", .green))
        }
        if !appState.profile.primaryGoal.isEmpty {
            items.append(("target", appState.profile.primaryGoal, .orange))
        }
        items.append(("calendar", L.t("timesPerWeek", lang).replacingOccurrences(of: "%@", with: "\(appState.profile.workoutsPerWeek)"), .blue))
        if !appState.profile.weakPoints.isEmpty {
            let focus = appState.profile.weakPoints.prefix(2).joined(separator: " + ")
            items.append(("flame.fill", focus, .red))
        }
        if !appState.profile.trainingLocation.isEmpty {
            items.append(("building.2.fill", appState.profile.trainingLocation, .purple))
        }
        return items
    }

    // MARK: - Today's Goal Hero

    private var todayGoalHero: some View {
        Group {
            if let workout = todayWorkout {
                let isCompleted = appState.isDayCompleted(workout.dayLabel)
                let accentColor = workoutAccentColor(workout)

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(L.t("todaysGoal", lang))
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(accentColor)
                                    .tracking(1.2)
                                if isCompleted {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                }
                            }

                            Text(workout.isRestDay ? L.t("restAndRecover", lang) : workout.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            if !workout.isRestDay {
                                HStack(spacing: 12) {
                                    Label("\(estimatedMinutes(workout))min", systemImage: "clock")
                                    Label(workoutDifficulty(workout), systemImage: "flame")
                                    Label("\(workout.exercises.count)", systemImage: "list.bullet")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if !workout.isRestDay {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                                    .frame(width: 60, height: 60)

                                let exercisesDone = isCompleted ? workout.exercises.count : 0
                                let progress = workout.exercises.isEmpty ? 0.0 : Double(exercisesDone) / Double(workout.exercises.count)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        accentColor,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))

                                Image(systemName: isCompleted ? "checkmark" : workout.icon)
                                    .font(.system(size: isCompleted ? 18 : 20))
                                    .foregroundStyle(isCompleted ? .green : accentColor)
                            }
                        }
                    }

                    if !workout.isRestDay {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.vertical, 14)

                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text(isCompleted ? "✓" : "+\(100 + workout.exercises.count * 10)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(isCompleted ? .green : .yellow)
                                Text(L.t("xpReward", lang))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1, height: 28)

                            VStack(spacing: 2) {
                                Text("\(nextTierPoints - appState.profile.points)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.cyan)
                                Text(L.t("toNextTier", lang).replacingOccurrences(of: "%@", with: nextTierName))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1, height: 28)

                            VStack(spacing: 2) {
                                Text(workout.focusAreas.first ?? "–")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(L.t("target", lang))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if !isCompleted {
                            Button(action: { selectedDay = workout }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 12))
                                    Text(L.t("startWorkout", lang))
                                        .font(.subheadline.weight(.bold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(accentColor)
                                .clipShape(.rect(cornerRadius: 14))
                            }
                            .padding(.top, 14)
                            .sensoryFeedback(.impact(weight: .medium), trigger: selectedDay?.id)
                        }
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [accentColor.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(accentColor.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Weekly Streak

    private var weeklyStreakSection: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    Text(L.t("weeklyStreak", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("\(completedCount)/\(appState.profile.workoutsPerWeek)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(.capsule)
            }

            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
            let fullLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

            HStack(spacing: 0) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                    let completed = appState.isDayCompleted(fullLabels[index])
                    let isToday = index == todayIndex

                    VStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isToday ? .white : .white.opacity(0.35))

                        ZStack {
                            Circle()
                                .fill(
                                    completed ? Color.green :
                                    isToday ? Color.white.opacity(0.12) :
                                    Color.white.opacity(0.05)
                                )
                                .frame(width: 34, height: 34)

                            if completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            } else if isToday {
                                Circle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text(L.t("streakDaysCount", lang).replacingOccurrences(of: "%@", with: "\(appState.profile.currentStreak)"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if completedCount >= appState.profile.workoutsPerWeek {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text(L.t("perfectWeek", lang))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                }

                Spacer()
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - Scan Insight (Enhanced)

    private var scanInsightCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text(L.t("scanInsight", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        insightBullet(icon: "target", text: L.t("focusOnArea", lang).replacingOccurrences(of: "%@", with: appState.profile.weakPoints.prefix(2).joined(separator: " & ")), color: .orange)

                        if !appState.profile.strongPoints.isEmpty {
                            insightBullet(icon: "checkmark.seal.fill", text: L.t("lookingStrongArea", lang).replacingOccurrences(of: "%@", with: appState.profile.strongPoints.first ?? ""), color: .green)
                        }

                        if let days = daysSinceLastScan {
                            insightBullet(icon: "clock.fill", text: L.t("scannedDaysAgo", lang).replacingOccurrences(of: "%@", with: "\(days)"), color: .blue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", appState.profile.latestScore ?? 0))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(L.t("score", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                bodyDiagramView

                Spacer()

                if let days = daysSinceLastScan {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: days <= 14 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(days <= 14 ? L.t("onTrack", lang) : L.t("scanOverdue", lang))
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(days <= 14 ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((days <= 14 ? Color.green : Color.orange).opacity(0.12))
                        .clipShape(.capsule)

                        Text(L.t("consistencyPercent", lang).replacingOccurrences(of: "%@", with: "\(min(100, appState.profile.totalScans * 25))"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.06), Color.white.opacity(0.02)],
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

    private func insightBullet(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var bodyDiagramView: some View {
        HStack(spacing: 3) {
            let weakLower = appState.profile.weakPoints.lowercased()
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 14, height: 14)
                RoundedRectangle(cornerRadius: 2)
                    .fill(weakLower.contains(where: { "chest,back,core,ab".contains($0) }) ? Color.orange.opacity(0.5) : Color.white.opacity(0.12))
                    .frame(width: 18, height: 22)
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(weakLower.contains(where: { "leg,quad,hamstring,glute,calf".contains($0) }) ? Color.orange.opacity(0.5) : Color.white.opacity(0.12))
                        .frame(width: 7, height: 24)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(weakLower.contains(where: { "leg,quad,hamstring,glute,calf".contains($0) }) ? Color.orange.opacity(0.5) : Color.white.opacity(0.12))
                        .frame(width: 7, height: 24)
                }
            }

            VStack(spacing: 4) {
                ForEach(appState.profile.weakPoints.prefix(3), id: \.self) { point in
                    Text(point)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 3))
                }
            }
        }
    }

    private var promptScanCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text(L.t("scanToPersonalize", lang))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(L.t("completeScanForPlan", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - Focus Areas (Interactive)

    private var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text(L.t("focusAreas", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            ForEach(appState.profile.weakPoints.prefix(4), id: \.self) { point in
                let priority = focusAreaPriority(point)
                Button(action: { selectedFocusItem = FocusAreaItem(area: point) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(priority.color.opacity(0.12))
                                .frame(width: 44, height: 44)

                            Image(systemName: muscleGroupIcon(point))
                                .font(.system(size: 18))
                                .foregroundStyle(priority.color)
                                .symbolRenderingMode(.hierarchical)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(point)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(focusAreaSubtitle(point))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: priority.icon)
                                .font(.system(size: 9))
                            Text(priority.localizedLabel(lang))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(priority.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priority.color.opacity(0.12))
                        .clipShape(.capsule)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .sensoryFeedback(.selection, trigger: selectedFocusItem?.id)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - AI Coach Floating Button

    private var aiFloatingButton: some View {
        Button(action: { showCoach = true }) {
            HStack(spacing: 0) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.45, blue: 1.0), Color(red: 0.55, green: 0.35, blue: 0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .shadow(color: Color(red: 0.4, green: 0.35, blue: 1.0).opacity(0.45), radius: 14, y: 6)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .sensoryFeedback(.impact(weight: .light), trigger: showCoach)
    }

    private var dailyCoachMessage: String {
        let score = appState.profile.latestScore ?? 0
        let streak = appState.profile.currentStreak
        let weakPoints = appState.profile.weakPoints

        if streak >= 7 {
            return "Incredible streak! \(streak) days strong. Your discipline is building real results. Keep pushing through plateaus."
        }
        if score >= 7 {
            return "Your physique is trending upward. Stay consistent this week and focus on progressive overload for continued gains."
        }
        if !weakPoints.isEmpty {
            return "Your plan targets \(weakPoints.prefix(2).joined(separator: " and ")). Prioritize these areas with proper form and mind-muscle connection."
        }
        if streak >= 3 {
            return "Nice momentum with \(streak) consecutive days! Recovery is equally important — make sure you're sleeping 7-8 hours."
        }
        return "Consistency beats intensity. Show up today and your future self will thank you. Every rep counts toward your goal."
    }

    private var suggestedQuestions: [String] {
        var questions = ["What should I eat today?"]
        if !appState.profile.weakPoints.isEmpty {
            questions.append("How do I improve \(appState.profile.weakPoints.first ?? "weak areas")?")
        }
        questions.append("Fix my weak core")
        questions.append("Best shoulder exercises?")
        return questions
    }

    // MARK: - Compete Integration

    private var competeIntegrationCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                Text(L.t("competeBonus", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(appState.profile.tier)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(.capsule)
            }

            if let workout = todayWorkout, !workout.isRestDay {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text(L.t("completeForPointsMsg", lang).replacingOccurrences(of: "%@", with: workout.name).replacingOccurrences(of: "%@", with: "\(100 + workout.exercises.count * 10)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color.yellow.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))
            }

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(appState.profile.points)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(L.t("points", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)

                VStack(spacing: 2) {
                    Text("\(appState.profile.currentStreak)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(L.t("streak", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)

                VStack(spacing: 2) {
                    Text("#\(leaderboardPosition)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.green)
                    Text(L.t("rank", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.04), Color.white.opacity(0.02)],
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

    private var leaderboardPosition: Int {
        let pts = appState.profile.points
        if pts >= 12000 { return 1 }
        if pts >= 9000 { return 3 }
        if pts >= 5000 { return 8 }
        if pts >= 2000 { return 14 }
        if pts >= 500 { return 24 }
        return 42
    }

    // MARK: - Weekly Plan

    private var weeklyPlanSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("thisWeek", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(L.t("timesPerWeek", lang).replacingOccurrences(of: "%@", with: "\(appState.profile.workoutsPerWeek)"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
        let accentColor = workoutAccentColor(workout)

        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(workout.dayLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isToday ? .white : .white.opacity(0.35))
                if isToday {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 32)

            ZStack {
                Image(systemName: workout.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(
                        completed ? .green :
                        workout.isRestDay ? .white.opacity(0.2) : accentColor
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        completed ? Color.green.opacity(0.12) :
                        accentColor.opacity(0.12)
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
                        Text(L.t("doneLabel", lang))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(.capsule)
                    } else if workout.isWeakPointFocus {
                        Text(L.t("focusLabel", lang))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(.capsule)
                    }
                }

                if !workout.isRestDay {
                    HStack(spacing: 8) {
                        Text(workout.focusAreas.joined(separator: " · "))
                            .lineLimit(1)
                        Text("·")
                        Text("\(estimatedMinutes(workout))min")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                } else {
                    Text(workout.focusAreas.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !workout.isRestDay {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(workout.exercises.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Text(workoutDifficulty(workout))
                        .font(.system(size: 9))
                        .foregroundStyle(accentColor.opacity(0.6))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(13)
        .background(
            completed ? Color.green.opacity(0.04) :
            isToday ? accentColor.opacity(0.06) : Color.white.opacity(0.04)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            isToday && !completed ?
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accentColor.opacity(0.15), lineWidth: 1) : nil
        )
    }

    // MARK: - Next Scan Reminder

    private var nextScanReminderCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let days = daysSinceLastScan {
                        let remaining = max(14 - days, 0)
                        Text(remaining > 0 ? L.t("nextScanDays", lang).replacingOccurrences(of: "%@", with: "\(remaining)") : L.t("timeForNewScan", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L.t("keepConsistent", lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L.t("completeFirstScan", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L.t("trackProgress", lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.06), Color.white.opacity(0.02)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.mint)
                Text(L.t("thisWeek", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 0) {
                summaryItem(
                    value: "\(completedCount)/\(appState.profile.workoutsPerWeek)",
                    label: L.t("workouts", lang),
                    color: .green
                )
                summaryDivider
                summaryItem(
                    value: "\(appState.profile.currentStreak)",
                    label: L.t("dayStreak", lang),
                    color: .orange
                )
                summaryDivider
                summaryItem(
                    value: "\(weeklyXP)",
                    label: L.t("xpEarned", lang),
                    color: .yellow
                )
            }

            if !appState.profile.weakPoints.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("\(L.t("improvementAreas", lang)): \(appState.profile.weakPoints.prefix(2).joined(separator: " + "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color.cyan.opacity(0.05))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    // MARK: - Helpers

    private func workoutAccentColor(_ workout: WorkoutDay) -> Color {
        if workout.isRestDay { return .gray }
        let name = workout.name.lowercased()
        if name.contains("push") { return .red }
        if name.contains("pull") { return .blue }
        if name.contains("leg") { return .purple }
        if name.contains("upper") { return .cyan }
        if name.contains("lower") || name.contains("core") { return .orange }
        if name.contains("recovery") { return .teal }
        if name.contains("weak") || name.contains("focus") { return .orange }
        if name.contains("full") { return .green }
        return .blue
    }

    private func estimatedMinutes(_ workout: WorkoutDay) -> Int {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        return max(totalSets * 3, 15)
    }

    private func workoutDifficulty(_ workout: WorkoutDay) -> String {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        if totalSets >= 20 { return L.t("hard", lang) }
        if totalSets >= 12 { return L.t("medium", lang) }
        return L.t("easy", lang)
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

    private func focusAreaPriority(_ area: String) -> FocusAreaPriority {
        let weakPoints = appState.profile.weakPoints
        guard let index = weakPoints.firstIndex(of: area) else { return .maintaining }
        if index == 0 { return .high }
        if index <= 1 { return .moderate }
        return .maintaining
    }

    private func focusAreaScore(_ area: String) -> Double {
        let base = appState.profile.latestScore ?? 5.0
        let priority = focusAreaPriority(area)
        switch priority {
        case .high: return max(base - 2.0, 1.0)
        case .moderate: return max(base - 1.0, 2.0)
        case .maintaining: return base
        }
    }

    private func focusAreaSubtitle(_ area: String) -> String {
        let lower = area.lowercased()
        if lower.contains("shoulder") { return "Wider frame, better posture" }
        if lower.contains("chest") { return "Upper body pressing power" }
        if lower.contains("back") { return "V-taper and posture" }
        if lower.contains("arm") { return "Complete physique" }
        if lower.contains("leg") { return "Foundation of strength" }
        if lower.contains("glute") { return "Hip power and stability" }
        if lower.contains("core") || lower.contains("ab") { return "Stability and protection" }
        if lower.contains("calf") { return "Lower body completion" }
        return "Targeted improvement area"
    }

    private func focusAreaExercises(_ area: String) -> [String] {
        let lower = area.lowercased()
        let isGym = appState.profile.trainingLocation.lowercased().contains("gym")
        if lower.contains("shoulder") {
            return isGym ? ["Overhead Press", "Lateral Raises", "Face Pulls", "Arnold Press", "Rear Delt Flyes"] : ["Pike Push-Ups", "Lateral Raises", "Band Pull-Aparts", "Handstand Progression"]
        }
        if lower.contains("chest") {
            return isGym ? ["Bench Press", "Incline DB Press", "Cable Flyes", "Dips", "Push-Ups"] : ["Push-Ups", "Decline Push-Ups", "Wide Push-Ups", "Dips"]
        }
        if lower.contains("back") {
            return isGym ? ["Barbell Rows", "Lat Pulldown", "Cable Row", "Face Pulls", "Deadlift"] : ["Pull-Ups", "Inverted Rows", "Superman Hold", "Band Rows"]
        }
        if lower.contains("leg") {
            return isGym ? ["Squats", "Romanian Deadlift", "Leg Press", "Lunges", "Calf Raises"] : ["Bulgarian Split Squats", "Pistol Squats", "Jump Squats", "Wall Sits"]
        }
        if lower.contains("core") || lower.contains("ab") {
            return ["Planks", "Hanging Leg Raises", "Cable Crunches", "Bicycle Crunches", "Ab Wheel"]
        }
        return ["Targeted Volume Work", "Progressive Overload", "Mind-Muscle Connection"]
    }

    // MARK: - Exercises helpers

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

    // MARK: - Plan Generation (unchanged logic)

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
        return WorkoutDay(dayLabel: "TUE", name: "Pull Day", focusAreas: ["Back", "Biceps", "Rear Delts"], icon: "figure.strengthtraining.functional", exercises: exercises, isWeakPointFocus: weakFocus)
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

nonisolated struct FocusAreaItem: Identifiable, Sendable {
    let id: String
    let area: String

    init(area: String) {
        self.id = area
        self.area = area
    }
}

extension Array where Element == String {
    func lowercased() -> String {
        self.joined(separator: ",").lowercased()
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
