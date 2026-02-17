import SwiftUI

struct CompeteView: View {
    @Environment(AppState.self) private var appState

    private var lang: String { appState.profile.selectedLanguage }
    @State private var showBattleSetup: Bool = false
    @State private var selectedLeaderboardTab: LeaderboardTab = .thisWeek
    @State private var appeared: Bool = false
    @State private var streakFireTrigger: Int = 0
    @State private var challengesExpanded: Bool = false

    private var currentTier: CompeteTier { CompeteTier.current(for: appState.profile.points) }
    private var nextTier: CompeteTier? { CompeteTier.next(for: appState.profile.points) }

    private var xpProgress: Double {
        guard let next = nextTier else { return 1.0 }
        let progressInTier = Double(appState.profile.points - currentTier.minPoints)
        let tierRange = Double(next.minPoints - currentTier.minPoints)
        return min(max(progressInTier / tierRange, 0), 1.0)
    }

    private var achievements: [Achievement] {
        [
            Achievement(id: "first_win", title: "First Blood", description: "Win your first battle", icon: "flame.fill", requiredValue: 1, currentValue: min(appState.profile.totalWorkouts > 0 ? 1 : 0, 1), xpReward: 100, tier: .bronze),
            Achievement(id: "streak_7", title: "Week Warrior", description: "7-day workout streak", icon: "flame.fill", requiredValue: 7, currentValue: min(appState.profile.currentStreak, 7), xpReward: 500, tier: .silver),
            Achievement(id: "battles_10", title: "Gladiator", description: "Complete 10 battles", icon: "figure.mixed.cardio", requiredValue: 10, currentValue: min(appState.profile.totalScans, 10), xpReward: 750, tier: .gold),
            Achievement(id: "workouts_25", title: "Iron Will", description: "Complete 25 workouts", icon: "figure.strengthtraining.traditional", requiredValue: 25, currentValue: min(appState.profile.totalWorkouts, 25), xpReward: 1000, tier: .gold),
            Achievement(id: "streak_30", title: "Unstoppable", description: "30-day streak", icon: "bolt.fill", requiredValue: 30, currentValue: min(appState.profile.currentStreak, 30), xpReward: 2000, tier: .diamond),
            Achievement(id: "diamond", title: "Diamond League", description: "Reach Diamond tier", icon: "diamond.fill", requiredValue: 10000, currentValue: appState.profile.points, xpReward: 5000, tier: .diamond),
        ]
    }

    private var seasonInfo: SeasonInfo {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let seasonName: String
        let seasonNum: Int
        if month <= 3 { seasonName = "Winter Bulk"; seasonNum = 1 }
        else if month <= 6 { seasonName = "Spring Cut"; seasonNum = 2 }
        else if month <= 9 { seasonName = "Summer Shred"; seasonNum = 3 }
        else { seasonName = "Fall Gains"; seasonNum = 4 }

        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -(calendar.component(.day, from: now))), to: now) ?? now
        let daysLeft = max(calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0, 0)

        return SeasonInfo(name: seasonName, number: seasonNum, daysRemaining: daysLeft, totalDays: 30, exclusiveBadge: "trophy.fill")
    }

    private let leaderboardData: [LeaderboardEntry] = [
        LeaderboardEntry(id: "1", rank: 1, name: "Alex M.", points: 12450, tier: "Diamond", xpToday: 340, rankChange: 0),
        LeaderboardEntry(id: "2", rank: 2, name: "Sarah K.", points: 11200, tier: "Diamond", xpToday: 280, rankChange: 1),
        LeaderboardEntry(id: "3", rank: 3, name: "Jordan R.", points: 9800, tier: "Platinum", xpToday: 210, rankChange: -1),
        LeaderboardEntry(id: "4", rank: 4, name: "Casey T.", points: 8600, tier: "Platinum", xpToday: 175, rankChange: 2),
        LeaderboardEntry(id: "5", rank: 5, name: "Morgan L.", points: 7200, tier: "Gold", xpToday: 120, rankChange: 0),
        LeaderboardEntry(id: "6", rank: 6, name: "Riley P.", points: 5400, tier: "Gold", xpToday: 95, rankChange: -2),
        LeaderboardEntry(id: "7", rank: 7, name: "Taylor W.", points: 4100, tier: "Gold", xpToday: 60, rankChange: 1),
    ]

    private let activityFeed: [ActivityFeedItem] = [
        ActivityFeedItem(id: "a1", userName: "Alex M.", action: "reached", detail: "Diamond tier", icon: "diamond.fill", timeAgo: "2h"),
        ActivityFeedItem(id: "a2", userName: "Sarah K.", action: "won a", detail: "physique battle", icon: "figure.mixed.cardio", timeAgo: "3h"),
        ActivityFeedItem(id: "a3", userName: "Jordan R.", action: "completed", detail: "7-day streak", icon: "flame.fill", timeAgo: "5h"),
        ActivityFeedItem(id: "a4", userName: "Casey T.", action: "unlocked", detail: "Gladiator badge", icon: "trophy.fill", timeAgo: "8h"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.bottom, 24)

                    seasonBanner
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    activeChallenge
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    battleCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    weeklyRingsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    challengesGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    leaderboardSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    achievementsGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    socialFeed
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("compete", lang))
            .navigationBarTitleDisplayMode(.large)
                        .sheet(isPresented: $showBattleSetup) {
                BattleSetupView()
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            TierBadgeView(tier: currentTier.name, points: appState.profile.points, size: 90)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.5)

            VStack(spacing: 6) {
                Text(currentTier.name.uppercased())
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .tracking(3)
                    .foregroundStyle(tierGradient)

                Text("\(appState.profile.points) XP")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            if let next = nextTier {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 8)

                            Capsule()
                                .fill(tierGradient)
                                .frame(width: max(geo.size.width * xpProgress, 8), height: 8)
                                .shadow(color: tierColor.opacity(0.4), radius: 6)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)

                    Text("\(next.minPoints - appState.profile.points) XP to \(next.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 32) {
                statPill(value: "\(appState.profile.points)", label: "XP", icon: "bolt.fill", color: .yellow)

                if appState.profile.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                            .symbolEffect(.bounce, value: streakFireTrigger)
                        Text("\(appState.profile.currentStreak)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    statPill(value: "0", label: "streak", icon: "flame.fill", color: .orange)
                }

                statPill(value: "\(appState.profile.totalWorkouts)", label: "wins", icon: "trophy.fill", color: .green)
            }
        }
        .padding(.vertical, 24)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                appeared = true
            }
            streakFireTrigger += 1
        }
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Season Banner

    private var seasonBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("SEASON \(seasonInfo.number)")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(.purple)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(seasonInfo.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(seasonInfo.daysRemaining) \(L.t("daysRemaining", lang))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("ENDS")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text("\(seasonInfo.daysRemaining)d")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.purple)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.08), Color.purple.opacity(0.02)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Active Challenge

    private var activeChallenge: some View {
        let weeklyProgress = Double(appState.workoutsThisWeek) / max(Double(appState.profile.workoutsPerWeek), 1)
        let isComplete = appState.workoutsThisWeek >= appState.profile.workoutsPerWeek

        return VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(L.t("activeChallenge", lang))
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if !isComplete {
                    Text("🔥 \(max(7 - Calendar.current.component(.weekday, from: Date()), 0))d left")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 16) {
                ZStack {
                    RingChartView(
                        progress: weeklyProgress,
                        lineWidth: 6,
                        gradient: isComplete ? [.green, .mint] : [.orange, .yellow],
                        size: 56
                    )

                    Text("\(appState.workoutsThisWeek)/\(appState.profile.workoutsPerWeek)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("weeklyWarrior", lang))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Complete all \(appState.profile.workoutsPerWeek) planned workouts this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("+300")
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                        .foregroundStyle(isComplete ? .green : .yellow)
                    Text("XP")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.06), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Battle Card (Cinematic)

    private var battleCard: some View {
        Button {
            showBattleSetup = true
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ZStack {
                        Color(white: 0.08)
                        Image(systemName: "figure.stand")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.quaternary)
                        VStack {
                            Spacer()
                            Text(L.t("you", lang))
                                .font(.system(.caption2, design: .rounded, weight: .black))
                                .tracking(2)
                                .foregroundStyle(.green)
                                .padding(6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)

                    ZStack {
                        Text("VS")
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.red)
                            .shadow(color: .red.opacity(0.5), radius: 8)
                    }
                    .frame(width: 50)
                    .frame(height: 120)
                    .background(
                        LinearGradient(
                            colors: [Color.red.opacity(0.15), Color.red.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    ZStack {
                        Color(white: 0.08)
                        Image(systemName: "figure.stand")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.quaternary)
                        VStack {
                            Spacer()
                            Text("???")
                                .font(.system(.caption2, design: .rounded, weight: .black))
                                .tracking(2)
                                .foregroundStyle(.red)
                                .padding(6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 18, topTrailing: 18)))

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("physiqueBattle", lang))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("Upload photos • AI judges • Get mogged 💀")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 8) {
                        battleTag("⚡ +50 XP")
                        battleTag("🏆 Win Streak")
                        battleTag("📸 Share")
                        Spacer()
                    }
                }
                .padding(16)
            }
            .background(Color.white.opacity(0.03))
            .clipShape(.rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.red.opacity(0.1), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showBattleSetup)
    }

    private func battleTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
    }

    // MARK: - Weekly Rings

    private var weeklyRingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L.t("thisWeek", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(L.t("week", lang)) \(Calendar.current.component(.weekOfYear, from: Date()))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 24) {
                TripleRingView(
                    moveProgress: Double(appState.workoutsThisWeek) / max(Double(appState.profile.workoutsPerWeek), 1),
                    trainProgress: Double(min(appState.totalWorkoutMinutes, 300)) / 300.0,
                    competeProgress: Double(min(appState.profile.points, 1000)) / 1000.0
                )

                VStack(alignment: .leading, spacing: 12) {
                    ringLegend(color: .red, label: L.t("compete", lang), value: "\(appState.profile.points) XP")
                    ringLegend(color: .green, label: L.t("train", lang), value: "\(appState.totalWorkoutMinutes)m")
                    ringLegend(color: .cyan, label: L.t("move", lang), value: "\(appState.workoutsThisWeek)/\(appState.profile.workoutsPerWeek)")
                }
            }

            weekdayDots
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func ringLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        }
    }

    private var weekdayDots: some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let isCompleted = appState.profile.completedDaysThisWeek.contains(dayLabels[index])
                let isToday = index == todayIndex

                VStack(spacing: 6) {
                    Text(days[index])
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(isToday ? .white : .white.opacity(0.3))

                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.green : Color.white.opacity(0.06))
                            .frame(width: 28, height: 28)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                        } else if isToday {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Challenges Grid

    private var challengesGrid: some View {
        let visibleChallenges = challengesExpanded ? challenges : Array(challenges.prefix(2))

        return VStack(spacing: 14) {
            HStack {
                Text(L.t("challenges", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(challenges.filter { $0.completed }.count)/\(challenges.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(Array(visibleChallenges.enumerated()), id: \.element.id) { index, challenge in
                challengeRow(challenge, index: index)
            }

            if challenges.count > 2 {
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        challengesExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(challengesExpanded ? L.t("showLess", lang) : "\(L.t("challenges", lang)) (\(challenges.count))")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: challengesExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .sensoryFeedback(.selection, trigger: challengesExpanded)
            }
        }
    }

    private var challenges: [(id: String, title: String, description: String, reward: Int, icon: String, progress: Double, progressText: String, completed: Bool, priority: String)] {
        [
            (id: "c1", title: "7-Day Streak", description: "Work out 7 days in a row", reward: 500, icon: "flame.fill",
             progress: Double(min(appState.profile.currentStreak, 7)) / 7.0,
             progressText: "\(min(appState.profile.currentStreak, 7))/7 days",
             completed: appState.profile.currentStreak >= 7, priority: "🔥 High"),
            (id: "c2", title: "First Scan", description: "Complete your first body scan", reward: 200, icon: "camera.viewfinder",
             progress: appState.profile.totalScans > 0 ? 1.0 : 0.0,
             progressText: appState.profile.totalScans > 0 ? "Done" : "0/1",
             completed: appState.profile.totalScans > 0, priority: "⚡ Medium"),
            (id: "c3", title: "Iron Will", description: "Complete 10 total workouts", reward: 500, icon: "figure.strengthtraining.traditional",
             progress: Double(min(appState.profile.totalWorkouts, 10)) / 10.0,
             progressText: "\(min(appState.profile.totalWorkouts, 10))/10",
             completed: appState.profile.totalWorkouts >= 10, priority: "🔥 High"),
            (id: "c4", title: "Early Riser", description: "5 workouts before 9 AM", reward: 150, icon: "sunrise.fill",
             progress: Double(earlyWorkouts) / 5.0,
             progressText: "\(earlyWorkouts)/5",
             completed: earlyWorkouts >= 5, priority: "✅ Bonus"),
            (id: "c5", title: "??? Mystery", description: "Unlock after 3 challenge wins", reward: 1000, icon: "lock.fill",
             progress: 0, progressText: "Locked",
             completed: false, priority: "🔒 Locked"),
        ]
    }

    private var earlyWorkouts: Int {
        let cal = Calendar.current
        return appState.profile.workoutLogs.filter { cal.component(.hour, from: $0.date) < 9 }.count
    }

    private func challengeRow(_ challenge: (id: String, title: String, description: String, reward: Int, icon: String, progress: Double, progressText: String, completed: Bool, priority: String), index: Int) -> some View {
        let isLocked = challenge.id == "c5" && challenges.filter({ $0.completed }).count < 3

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(challenge.completed ? Color.green.opacity(0.12) : (isLocked ? Color.white.opacity(0.03) : Color.white.opacity(0.06)))
                    .frame(width: 44, height: 44)

                Image(systemName: challenge.completed ? "checkmark.circle.fill" : challenge.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(challenge.completed ? .green : (isLocked ? .white.opacity(0.15) : .white.opacity(0.5)))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLocked ? .white.opacity(0.2) : .white)

                    Text(challenge.priority)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        Capsule()
                            .fill(challenge.completed ? Color.green : Color.yellow)
                            .frame(width: max(geo.size.width * min(max(challenge.progress, 0), 1), 0), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(challenge.reward)")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(challenge.completed ? .green : .yellow)
                Text(challenge.progressText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(challenge.completed ? Color.green.opacity(0.03) : Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 14))
        .opacity(isLocked ? 0.5 : 1)
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("leaderboard", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(LeaderboardTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.snappy) {
                            selectedLeaderboardTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(selectedLeaderboardTab == tab ? .white : .white.opacity(0.35))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedLeaderboardTab == tab ? Color.white.opacity(0.1) : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(leaderboardData) { entry in
                    leaderboardRow(entry)
                }

                userLeaderboardRow
            }
        }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if entry.rank <= 3 {
                    Text(entry.rank == 1 ? "🥇" : entry.rank == 2 ? "🥈" : "🥉")
                        .font(.system(size: 18))
                } else {
                    Text("\(entry.rank)")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28)

            Circle()
                .fill(tierColorFor(entry.tier).opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(String(entry.name.prefix(1)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tierColorFor(entry.tier))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(entry.tier)
                        .font(.caption2)
                        .foregroundStyle(tierColorFor(entry.tier).opacity(0.7))
                    if entry.xpToday > 0 {
                        Text("• +\(entry.xpToday) today")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.points)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)

                if entry.rankChange != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: entry.rankChange > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(abs(entry.rankChange))")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(entry.rankChange > 0 ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var userLeaderboardRow: some View {
        HStack(spacing: 12) {
            Text("—")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 28)

            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(String(appState.profile.name.prefix(1)).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(appState.profile.name.isEmpty ? "You" : appState.profile.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("(You)")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.6))
                }
                Text(appState.profile.tier)
                    .font(.caption2)
                    .foregroundStyle(tierColorFor(appState.profile.tier).opacity(0.7))
            }

            Spacer()

            Text("\(appState.profile.points)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Achievements Grid

    private var achievementsGrid: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("achievements", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(achievements.filter { $0.isUnlocked }.count)/\(achievements.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(achievements) { achievement in
                    achievementBadge(achievement)
                }
            }
        }
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? tierColorFor(achievement.tier.rawValue).opacity(0.15) : Color.white.opacity(0.04))
                    .frame(width: 52, height: 52)

                if achievement.isUnlocked {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(tierColorFor(achievement.tier.rawValue))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.quaternary)
                }

                if !achievement.isUnlocked {
                    Circle()
                        .trim(from: 0, to: achievement.progress)
                        .stroke(Color.yellow.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                }
            }

            Text(achievement.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? .white : .white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("+\(achievement.xpReward) XP")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? .green : .white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(achievement.isUnlocked ? tierColorFor(achievement.tier.rawValue).opacity(0.04) : Color.white.opacity(0.02))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Social Feed

    private var socialFeed: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("activity", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(L.t("recent", lang))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(activityFeed) { item in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: item.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        )

                    HStack(spacing: 0) {
                        Text(item.userName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.7))
                        Text(" \(item.action) ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Helpers

    private var tierGradient: LinearGradient {
        LinearGradient(colors: [tierColor, tierSecondaryColor], startPoint: .leading, endPoint: .trailing)
    }

    private var tierColor: Color {
        switch currentTier.name {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }

    private var tierSecondaryColor: Color {
        switch currentTier.name {
        case "Silver": return Color(red: 0.6, green: 0.6, blue: 0.65)
        case "Gold": return Color(red: 0.85, green: 0.65, blue: 0.0)
        case "Platinum": return Color(red: 0.4, green: 0.6, blue: 0.85)
        case "Diamond": return Color(red: 0.4, green: 0.7, blue: 1.0)
        default: return Color(red: 0.65, green: 0.35, blue: 0.10)
        }
    }

    private func tierColorFor(_ tier: String) -> Color {
        switch tier {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }
}
