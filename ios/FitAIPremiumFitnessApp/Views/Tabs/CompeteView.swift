import SwiftUI

struct CompeteView: View {
    @Environment(AppState.self) private var appState
    @Environment(TourManager.self) private var tourManager

    private var lang: String { appState.profile.selectedLanguage }
    @State private var showBattleSetup: Bool = false
    /// Set when a push notification deep-links into a specific challenge.
    /// CompeteView watches tourManager.pendingChallengeId, resolves the
    /// matching PopulatedChallenge, and presents ChallengeDetailSheet.
    @State private var pushOpenedChallenge: PopulatedChallenge? = nil
    @State private var selectedLeaderboardTab: LeaderboardTab = .thisWeek
    @State private var appeared: Bool = false
    @State private var streakFireTrigger: Int = 0
    @State private var challengesExpanded: Bool = false
    @State private var showFriends: Bool = false
    @State private var friendVM = FriendViewModel()
    /// Set when the user taps a friend bubble — drives a presentation of
    /// FriendProfileSheet with that friend's profile + head-to-head record.
    @State private var profileFriend: SocialProfileSummary? = nil
    @State private var showRankProgression: Bool = false
    @State private var realLeaderboard: [LeaderboardProfile] = []
    @State private var isLoadingLeaderboard: Bool = false
    @State private var leaderboardRefreshTask: Task<Void, Never>? = nil
    @Environment(\.scenePhase) private var scenePhase

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
            Achievement(id: "first_workout", title: "First Step", description: "Complete 1 workout", icon: "figure.walk", requiredValue: 1, currentValue: appState.profile.totalWorkouts, xpReward: 100, tier: .bronze),
            Achievement(id: "first_scan", title: "Self Aware", description: "Complete 1 body scan", icon: "camera.viewfinder", requiredValue: 1, currentValue: appState.profile.totalScans, xpReward: 150, tier: .bronze),
            Achievement(id: "streak_7", title: "Week Warrior", description: "7-day workout streak", icon: "flame.fill", requiredValue: 7, currentValue: appState.profile.currentStreak, xpReward: 500, tier: .silver),
            Achievement(id: "workouts_10", title: "Iron Starter", description: "Complete 10 workouts", icon: "dumbbell.fill", requiredValue: 10, currentValue: appState.profile.totalWorkouts, xpReward: 500, tier: .silver),
            Achievement(id: "scans_5", title: "Progress Tracker", description: "Complete 5 body scans", icon: "chart.line.uptrend.xyaxis", requiredValue: 5, currentValue: appState.profile.totalScans, xpReward: 600, tier: .silver),
            Achievement(id: "workouts_25", title: "Iron Will", description: "Complete 25 workouts", icon: "figure.strengthtraining.traditional", requiredValue: 25, currentValue: appState.profile.totalWorkouts, xpReward: 1000, tier: .gold),
            Achievement(id: "streak_30", title: "Unstoppable", description: "30-day workout streak", icon: "bolt.fill", requiredValue: 30, currentValue: appState.profile.currentStreak, xpReward: 2000, tier: .diamond),
            Achievement(id: "workouts_100", title: "Centurion", description: "Complete 100 workouts", icon: "rosette", requiredValue: 100, currentValue: appState.profile.totalWorkouts, xpReward: 3000, tier: .diamond),
            Achievement(id: "diamond", title: "Diamond League", description: "Reach 10,000 XP", icon: "diamond.fill", requiredValue: 10000, currentValue: appState.profile.points, xpReward: 5000, tier: .diamond),
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

    private var leaderboardData: [LeaderboardEntry] {
        let myUsername = appState.profile.username.lowercased()
        let entries = realLeaderboard.filter { $0.username != myUsername }
        return entries.prefix(20).enumerated().map { index, profile in
            LeaderboardEntry(
                id: profile.id,
                rank: index + 1,
                name: profile.displayName,
                points: profile.points,
                tier: profile.tier,
                xpToday: 0,
                rankChange: 0
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    liveTicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    battleCard
                        .tourAnchor(.competeBattleCard)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    friendsSection
                        .tourAnchor(.competeFriends)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    comingSoonCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .padding(.top, 8)
                .tourAutoScroll(tab: 2, proxy: scrollProxy)
            }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("compete", lang))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showBattleSetup) {
                BattleSetupView()
            }
            .sheet(isPresented: $showFriends) {
                FriendsView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $profileFriend) { friend in
                FriendProfileSheet(viewModel: friendVM, friend: friend)
            }
            .sheet(item: $pushOpenedChallenge) { challenge in
                ChallengeDetailSheet(viewModel: friendVM, challenge: challenge)
            }
            .onChange(of: tourManager.pendingChallengeId) { _, newId in
                guard let newId else { return }
                Task {
                    // Refresh first in case the deep-linked challenge isn't
                    // in the cached list yet (push fired before next refresh).
                    await friendVM.refresh()
                    if let match = friendVM.challenges.first(where: { $0.row.id == newId }) {
                        pushOpenedChallenge = match
                    }
                    // Always clear so the same id won't re-trigger on a
                    // subsequent unrelated tab change.
                    tourManager.pendingChallengeId = nil
                }
            }
            .task {
                friendVM.attach(appState)
                await friendVM.refresh()
                // Open the Realtime channel for friend_requests / challenges /
                // notifications / friendships. Channel auto-closes when the
                // tab disappears (see .onDisappear).
                await friendVM.startRealtime()
            }
            .onDisappear {
                Task { await friendVM.stopRealtime() }
            }
        }
    }

    private func startLeaderboardAutoRefresh() {
        stopLeaderboardAutoRefresh()
        leaderboardRefreshTask = Task { @MainActor in
            // Pseudo-realtime: poll every 15s while the Compete tab is visible.
            // Switching to Supabase Realtime would require linking the Realtime
            // SPM product and publishing the leaderboard_profiles table — this
            // gives a near-realtime feel without those changes.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { return }
                await syncAndLoadLeaderboard()
            }
        }
    }

    private func stopLeaderboardAutoRefresh() {
        leaderboardRefreshTask?.cancel()
        leaderboardRefreshTask = nil
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            Button {
                    showRankProgression = true
                } label: {
                    TierBadgeView(tier: currentTier.name, points: appState.profile.points, size: 90)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.5)
                .sensoryFeedback(.impact(weight: .light), trigger: showRankProgression)

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
                                .fill(Color(.systemGray5))
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
                        Text(L.t("streakLabel", lang))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    statPill(value: "0", label: L.t("streakLabel", lang), icon: "flame.fill", color: .orange)
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
                Text(L.t("endsLabel", lang))
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

                    Text("VS")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.red)
                        .shadow(color: .red.opacity(0.5), radius: 8)
                        .frame(width: 50)
                        .frame(height: 120)

                    ZStack {
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

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("physiqueBattle", lang))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(L.t("uploadPhotosCaption", lang))
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
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [.red.opacity(0.06), .orange.opacity(0.03), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(colors: [.red.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
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
            .background(Color(.systemGray5))
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
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.green.opacity(0.05), .cyan.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [.green.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
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
                        .foregroundStyle(isToday ? .primary : .tertiary)

                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.green : Color(.systemGray5))
                            .frame(width: 28, height: 28)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isToday {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1.5)
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
                    .background(Color(.secondarySystemGroupedBackground))
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
                    .fill(challenge.completed ? Color.green.opacity(0.12) : Color(.systemGray5))
                    .frame(width: 44, height: 44)

                Image(systemName: challenge.completed ? "checkmark.circle.fill" : challenge.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(challenge.completed ? .green : (isLocked ? Color(.systemGray4) : .secondary))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLocked ? .tertiary : .primary)

                    Text(challenge.priority)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                Text(challenge.description)
                    .font(.system(size: 11))
                    .foregroundStyle(isLocked ? .quaternary : .secondary)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
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
        .background(
            ZStack {
                challenge.completed ? Color.green.opacity(0.05) : Color(.secondarySystemGroupedBackground)
                if !challenge.completed {
                    LinearGradient(
                        colors: [.yellow.opacity(0.04), .orange.opacity(0.02), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
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
                            .foregroundStyle(selectedLeaderboardTab == tab ? .primary : .tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedLeaderboardTab == tab ? Color(.systemGray5) : Color.clear)
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
                        Text("• " + L.t("todayPlusFmt", lang).replacingOccurrences(of: "%@", with: "\(entry.xpToday)"))
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
        .background(
            ZStack {
                Color.primary.opacity(0.03)
                LinearGradient(
                    colors: [.purple.opacity(0.04), .blue.opacity(0.02), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    private var userLeaderboardRow: some View {
        HStack(spacing: 12) {
            Text("-")
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
                    if appState.profile.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    Text(L.t("youParen", lang))
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
                    .fill(achievement.isUnlocked ? tierColorFor(achievement.tier.rawValue).opacity(0.15) : Color(.systemGray5))
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
                .foregroundStyle(achievement.isUnlocked ? .primary : .tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(achievement.description)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 4)

            Text(achievement.isUnlocked
                 ? "+\(achievement.xpReward) XP"
                 : "\(min(achievement.currentValue, achievement.requiredValue))/\(achievement.requiredValue)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? .green : .yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(achievement.isUnlocked ? tierColorFor(achievement.tier.rawValue).opacity(0.06) : Color(.secondarySystemGroupedBackground))
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

            VStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text(L.t("noActivityYet", lang))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(L.t("noActivityDesc", lang))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("\(L.t("friendsAnd1v1", lang)) 👀")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                // Lights up only when at least one friend's `last_seen_at`
                // is within the past 5 min — real presence, not "you have
                // friends" decoration.
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .opacity(friendVM.friends.contains(where: { $0.isOnline }) ? 1 : 0)
                Spacer()
                Button {
                    showFriends = true
                } label: {
                    HStack(spacing: 4) {
                        Text(L.t("seeAll", lang))
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if friendVM.friends.isEmpty {
                Button {
                    showFriends = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("addFriendsTitle", lang))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(L.t("addFriendsDesc", lang))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 14))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button {
                            showFriends = true
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                Text("Add")
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(BouncyButtonStyle())

                        ForEach(friendVM.friends) { friend in
                            Button {
                                profileFriend = friend
                            } label: {
                                friendBubble(friend)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                }
                .contentMargins(.horizontal, 20)
                .padding(.horizontal, -20)

                if let rival = rivalOfTheWeek {
                    rivalOfTheWeekCard(rival)
                }

                if !friendVM.activeChallenges.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(friendVM.activeChallenges.prefix(2)) { challenge in
                            Button {
                                pushOpenedChallenge = challenge
                            } label: {
                                activeChallengeRow(challenge)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                }
            }
        }
    }

    /// Friend whose latest_score is closest to mine — surfaced as
    /// "Rival of the Week" suggestion. Server fires a weekly push for the
    /// same pick; the in-app card is computed locally so it's always live.
    private var rivalOfTheWeek: SocialProfileSummary? {
        guard let myScore = appState.profile.latestScore, myScore > 0 else { return nil }
        return friendVM.friends
            .filter { ($0.latestScore ?? 0) > 0 }
            .min(by: { abs(($0.latestScore ?? 0) - myScore) < abs(($1.latestScore ?? 0) - myScore) })
    }

    private func rivalOfTheWeekCard(_ rival: SocialProfileSummary) -> some View {
        Button {
            profileFriend = rival
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.32),
                                    Color.red.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle().strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.7)
                        )
                        .shadow(color: Color.orange.opacity(0.30), radius: 8, y: 2)
                    Image(systemName: "scope")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("RIVAL OF THE WEEK")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(.orange)
                    Text("@\(rival.username) · \(rival.latestScore.map { String(format: "%.1f", $0) } ?? "—")")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Closest score to yours. Challenge them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.orange.opacity(0.6))
            }
            .padding(14)
            // Gradient card matching the design language of the friend
            // rows in FriendsView — orange/red wash for the rival accent
            // + hairline stroke. Replaces the flat 4%-opacity background
            // that read as a generic grey box.
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.14),
                            Color.red.opacity(0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.35),
                                Color.red.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
            .shadow(color: Color.orange.opacity(0.10), radius: 14, y: 6)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Live ticker

    /// Auto-rotating one-line "what's happening" ribbon at the top of the
    /// Compete tab. Builds messages from friends + recent activity so the
    /// tab feels populated even when nothing's actively happening — Strava's
    /// pattern, scaled down. If there's truly nothing to show, the view
    /// hides itself.
    private var liveTicker: some View {
        TickerView(messages: tickerMessages)
    }

    private var tickerMessages: [String] {
        var msgs: [String] = []
        let active = friendVM.friends.filter { ($0.currentStreak ?? 0) > 0 }
        if !active.isEmpty {
            msgs.append("\(active.count) friend\(active.count == 1 ? "" : "s") active this week")
        }
        for friend in friendVM.friends.prefix(2) {
            if let streak = friend.currentStreak, streak >= 3 {
                msgs.append("🔥 @\(friend.username) on a \(streak)-day streak")
            }
        }
        for ch in friendVM.challenges.prefix(2) {
            switch ch.row.status {
            case "pending":
                msgs.append("🥊 @\(ch.otherUser.username) wants to battle")
            case "active":
                msgs.append("⚔️ Live battle with @\(ch.otherUser.username)")
            case "completed":
                msgs.append("🏁 Battle vs @\(ch.otherUser.username) finished")
            default: break
            }
        }
        if msgs.isEmpty && friendVM.friends.isEmpty {
            msgs.append("👋 Add friends to start battles")
        }
        return msgs
    }

    private func friendBubble(_ friend: SocialProfileSummary) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                FriendAvatarView(
                    photoURL: friend.profilePhotoURL,
                    symbolName: friend.avatarSystemName,
                    size: 56,
                    symbolSize: 22,
                    fallbackBackground: Color.orange.opacity(0.18),
                    symbolColor: .primary.opacity(0.7)
                )
                // Real presence dot — green if friend's `last_seen_at`
                // was within the last 5 min, otherwise hidden.
                if friend.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle().strokeBorder(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: -2, y: -2)
                }

                if let streak = friend.currentStreak, streak > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7))
                        Text("\(streak)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .offset(x: 4, y: 12)
                }
            }
            Text(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 72)
    }

    private func activeChallengeRow(_ challenge: PopulatedChallenge) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("vs @\(challenge.otherUser.username)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(challenge.row.category.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(challengeStatusText(challenge.row.status))
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(challengeStatusColor(challenge.row.status))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(challengeStatusColor(challenge.row.status).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func challengeStatusText(_ status: String) -> String {
        switch status {
        case "pending": return "Pending"
        case "accepted": return "Accepted"
        case "in_progress": return "Live"
        case "completed": return "Done"
        case "declined": return "Declined"
        case "expired": return "Expired"
        default: return status.capitalized
        }
    }

    private func challengeStatusColor(_ status: String) -> Color {
        switch status {
        case "pending": return .orange
        case "accepted": return .blue
        case "in_progress": return .purple
        case "completed": return .green
        case "declined", "expired": return .gray
        default: return .gray
        }
    }

    private func friendTierColor(_ tier: String) -> Color {
        switch tier {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }

    // MARK: - Coming Soon

    private var comingSoonCard: some View {
        let features: [(icon: String, title: String, desc: String, color: Color)] = [
            ("chart.line.uptrend.xyaxis", "Competitive Ranks", "Divisions, promotion matches, and seasonal placement", .orange),
            ("trophy.fill", "Weekly Tournaments", "Bracketed events with exclusive badges and rewards", .blue),
            ("person.3.fill", "Squads & Clans", "Team up with friends and climb the ladder together", .purple),
        ]

        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Coming Soon")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(feature.color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: feature.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(feature.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(feature.desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)

                    if idx < features.count - 1 {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
        .padding(20)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(colors: [.blue.opacity(0.12), .purple.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
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

    private func syncAndLoadLeaderboard() async {
        let profile = appState.profile
        if !profile.username.isEmpty {
            await LeaderboardService.shared.upsertProfile(
                username: profile.username,
                displayName: profile.name.isEmpty ? profile.username : profile.name,
                points: profile.points,
                tier: profile.tier,
                streak: profile.currentStreak,
                totalWorkouts: profile.totalWorkouts
            )
        }
        isLoadingLeaderboard = true
        realLeaderboard = await LeaderboardService.shared.fetchLeaderboard(limit: 50)
        isLoadingLeaderboard = false
    }
}

/// Tactile press style — scales the label down ~6% on touch and springs
/// back on release. Applied to the friend bubbles, Add chip, rival card,
/// and active challenge rows so the whole "Friends & 1v1" cluster feels
/// like one bouncy, tappable surface instead of a mix of flat buttons.
/// Spring is tuned to be felt but not cartoonish (extraBounce 0.35,
/// short duration so quick taps still register the rebound).
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(duration: 0.28, bounce: 0.35), value: configuration.isPressed)
    }
}
