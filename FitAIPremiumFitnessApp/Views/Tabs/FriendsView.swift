import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = FriendViewModel()
    @State private var showAddFriend: Bool = false
    @State private var friendToChallenge: Friend? = nil
    @State private var friendToRemove: Friend? = nil
    @State private var selectedSegment: Int = 0
    @State private var hapticTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    usernameCard

                    segmentControl

                    if selectedSegment == 0 {
                        friendsListSection
                    } else {
                        challengesSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(viewModel: viewModel)
            }
            .sheet(item: $friendToChallenge) { friend in
                ChallengeSetupSheet(viewModel: viewModel, friend: friend)
            }
            .confirmationDialog(
                "Remove Friend",
                isPresented: .init(
                    get: { friendToRemove != nil },
                    set: { if !$0 { friendToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let friend = friendToRemove {
                        withAnimation(.snappy) {
                            viewModel.removeFriend(friend)
                        }
                    }
                    friendToRemove = nil
                }
            } message: {
                if let friend = friendToRemove {
                    Text("Remove @\(friend.username) from your friends?")
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .onAppear {
                viewModel.loadSampleData()
                if !appState.profile.username.isEmpty {
                    viewModel.setUsername(appState.profile.username)
                }
            }
        }
    }

    private var usernameCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text("@")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                if viewModel.username.isEmpty {
                    Text("Set your username")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Friends can find you by username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("@\(viewModel.username)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Your username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(viewModel.friends.count)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.blue)
            Text("friends")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var segmentControl: some View {
        HStack(spacing: 4) {
            segmentButton(title: "Friends", index: 0, count: viewModel.friends.count)
            segmentButton(title: "Challenges", index: 1, count: viewModel.activeChallenges.count)
        }
        .padding(3)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 20)
    }

    private func segmentButton(title: String, index: Int, count: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedSegment = index
            }
            hapticTrigger += 1
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(selectedSegment == index ? .blue : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedSegment == index ? Color.blue.opacity(0.12) : Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(selectedSegment == index ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(selectedSegment == index ? Color(.systemBackground) : Color.clear)
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var friendsListSection: some View {
        VStack(spacing: 12) {
            if viewModel.friends.isEmpty {
                emptyFriendsState
            } else {
                ForEach(viewModel.friends) { friend in
                    friendRow(friend)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var emptyFriendsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No Friends Yet")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text("Add friends by their username and challenge them to 1v1 battles!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddFriend = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add Friend")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func friendRow(_ friend: Friend) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tierColor(friend.tier).opacity(0.12))
                    .frame(width: 50, height: 50)
                Text(friend.avatarEmoji)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(friend.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(friend.tier)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(tierColor(friend.tier))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierColor(friend.tier).opacity(0.1))
                        .clipShape(Capsule())
                }
                HStack(spacing: 8) {
                    Text("@\(friend.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if friend.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                            Text("\(friend.currentStreak)")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()

            Button {
                friendToChallenge = friend
                hapticTrigger += 1
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("1v1")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .contextMenu {
            Button {
                friendToChallenge = friend
            } label: {
                Label("Send 1v1 Challenge", systemImage: "bolt.fill")
            }
            Button(role: .destructive) {
                friendToRemove = friend
            } label: {
                Label("Remove Friend", systemImage: "person.badge.minus")
            }
        }
    }

    private var challengesSection: some View {
        VStack(spacing: 16) {
            if viewModel.activeChallenges.isEmpty && viewModel.completedChallenges.isEmpty {
                emptyChallengesState
            } else {
                if !viewModel.activeChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVE")
                            .font(.system(.caption2, design: .rounded, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.orange)
                            .padding(.leading, 4)

                        ForEach(viewModel.activeChallenges) { challenge in
                            challengeRow(challenge, isActive: true)
                        }
                    }
                }

                if !viewModel.completedChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("COMPLETED")
                            .font(.system(.caption2, design: .rounded, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.green)
                            .padding(.leading, 4)

                        ForEach(viewModel.completedChallenges.prefix(5)) { challenge in
                            challengeRow(challenge, isActive: false)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var emptyChallengesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No Challenges Yet")
                .font(.headline.weight(.bold))
            Text("Challenge a friend to a 1v1 physique battle!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func challengeRow(_ challenge: Challenge1v1, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.orange.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: isActive ? "bolt.fill" : "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? .orange : .green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("vs \(challenge.opponentName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(challenge.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(statusLabel(challenge.status))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(statusColor(challenge.status))
                }
            }

            Spacer()

            if challenge.status == .completed, let yourScore = challenge.challengerScore, let theirScore = challenge.opponentScore {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(yourScore >= theirScore ? "WON" : "LOST")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .foregroundStyle(yourScore >= theirScore ? .green : .red)
                    Text("\(String(format: "%.1f", yourScore)) - \(String(format: "%.1f", theirScore))")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(timeAgo(challenge.sentDate))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func statusLabel(_ status: ChallengeStatus) -> String {
        switch status {
        case .pending: return "Waiting..."
        case .accepted: return "Accepted"
        case .inProgress: return "In Progress"
        case .completed: return "Done"
        case .declined: return "Declined"
        case .expired: return "Expired"
        }
    }

    private func statusColor(_ status: ChallengeStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .declined: return .red
        case .expired: return .gray
        }
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
