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

    private let challenges: [(title: String, description: String, reward: Int, icon: String)] = [
        ("7-Day Streak", "Work out 7 days in a row", 500, "flame.fill"),
        ("First Scan", "Complete your first body scan", 200, "camera.viewfinder"),
        ("Push-Up Challenge", "100 push-ups in one session", 300, "figure.strengthtraining.traditional"),
        ("Early Bird", "Complete a workout before 7 AM", 150, "sunrise.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    statsHeader

                    leaderboardSection

                    challengesSection
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
            statItem(value: "#\(leaderboard.count + 1)", label: "Rank")
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

    private var challengesSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Challenges")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ForEach(challenges, id: \.title) { challenge in
                challengeCard(challenge)
            }
        }
    }

    private func challengeCard(_ challenge: (title: String, description: String, reward: Int, icon: String)) -> some View {
        HStack(spacing: 14) {
            Image(systemName: challenge.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(challenge.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("+\(challenge.reward)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.yellow)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }
}
