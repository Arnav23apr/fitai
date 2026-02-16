import SwiftUI

struct CompeteView: View {
    @Environment(AppState.self) private var appState

    private let leaderboard: [(rank: Int, name: String, points: Int, tier: String)] = [
        (1, "Alex M.", 12450, "Diamond"),
        (2, "Sarah K.", 11200, "Diamond"),
        (3, "Jordan R.", 9800, "Platinum"),
        (4, "Casey T.", 8600, "Platinum"),
        (5, "Morgan L.", 7200, "Gold"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    statsHeader

                    weeklyStatsCard

                    challengesSection

                    leaderboardSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.black)
            .navigationTitle("Compete")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statItem(value: "\(appState.profile.points)", label: "Points")
            divider
            statItem(value: appState.profile.tier, label: "Tier")
            divider
            statItem(value: "\(appState.profile.currentStreak)", label: "Streak")
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 36)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyStatsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 12) {
                weekStatBubble(
                    value: "\(appState.workoutsThisWeek)",
                    label: "Workouts",
                    icon: "dumbbell.fill",
                    color: .green
                )
                weekStatBubble(
                    value: "\(appState.totalWorkoutMinutes)m",
                    label: "Total Time",
                    icon: "clock.fill",
                    color: .blue
                )
                weekStatBubble(
                    value: "\(appState.profile.totalWorkouts)",
                    label: "All Time",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func weekStatBubble(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var challengesSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Challenges")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            challengeCard(
                title: "7-Day Streak",
                description: "Work out 7 days in a row",
                reward: 500,
                icon: "flame.fill",
                progress: Double(min(appState.profile.currentStreak, 7)) / 7.0,
                progressText: "\(min(appState.profile.currentStreak, 7))/7 days",
                completed: appState.profile.currentStreak >= 7
            )

            challengeCard(
                title: "First Scan",
                description: "Complete your first body scan",
                reward: 200,
                icon: "camera.viewfinder",
                progress: appState.profile.totalScans > 0 ? 1.0 : 0.0,
                progressText: appState.profile.totalScans > 0 ? "Completed" : "0/1 scans",
                completed: appState.profile.totalScans > 0
            )

            challengeCard(
                title: "Weekly Warrior",
                description: "Complete all planned workouts this week",
                reward: 300,
                icon: "trophy.fill",
                progress: Double(appState.workoutsThisWeek) / max(Double(appState.profile.workoutsPerWeek), 1),
                progressText: "\(appState.workoutsThisWeek)/\(appState.profile.workoutsPerWeek) workouts",
                completed: appState.workoutsThisWeek >= appState.profile.workoutsPerWeek
            )

            challengeCard(
                title: "Iron Will",
                description: "Complete 10 total workouts",
                reward: 500,
                icon: "figure.strengthtraining.traditional",
                progress: Double(min(appState.profile.totalWorkouts, 10)) / 10.0,
                progressText: "\(min(appState.profile.totalWorkouts, 10))/10 workouts",
                completed: appState.profile.totalWorkouts >= 10
            )

            challengeCard(
                title: "Early Riser",
                description: "Complete 5 workouts before 9 AM",
                reward: 150,
                icon: "sunrise.fill",
                progress: Double(earlyWorkouts) / 5.0,
                progressText: "\(earlyWorkouts)/5 workouts",
                completed: earlyWorkouts >= 5
            )
        }
    }

    private var earlyWorkouts: Int {
        let cal = Calendar.current
        return appState.profile.workoutLogs.filter { cal.component(.hour, from: $0.date) < 9 }.count
    }

    private func challengeCard(title: String, description: String, reward: Int, icon: String, progress: Double, progressText: String, completed: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: completed ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 18))
                    .foregroundStyle(completed ? .green : .white)
                    .frame(width: 42, height: 42)
                    .background(completed ? Color.green.opacity(0.12) : Color.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if completed {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("+\(reward)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(completed ? .green : .yellow)
                    Text("pts")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    let clampedProgress = min(max(progress, 0), 1)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)
                        Capsule()
                            .fill(completed ? Color.green : Color.yellow)
                            .frame(width: max(geo.size.width * clampedProgress, 0), height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(progressText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(completed ? Color.green.opacity(0.04) : Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            completed ?
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.green.opacity(0.1), lineWidth: 1) : nil
        )
    }

    private var leaderboardSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Leaderboard")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("This Week")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }

            VStack(spacing: 8) {
                ForEach(leaderboard, id: \.rank) { entry in
                    leaderboardRow(entry)
                }

                HStack(spacing: 14) {
                    Text("You")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.green)
                        .frame(width: 28)

                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(appState.profile.name.prefix(1)).uppercased())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.profile.name.isEmpty ? "You" : appState.profile.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Text(appState.profile.tier)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    Spacer()

                    Text("\(appState.profile.points)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .padding(12)
                .background(Color.green.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private func leaderboardRow(_ entry: (rank: Int, name: String, points: Int, tier: String)) -> some View {
        HStack(spacing: 14) {
            Text("\(entry.rank)")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(entry.rank <= 3 ? .yellow : .white.opacity(0.5))
                .frame(width: 28)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(entry.name.prefix(1)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(entry.tier)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            Text("\(entry.points)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }
}
