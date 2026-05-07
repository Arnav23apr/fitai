import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var viewModel = FriendViewModel()

    @State private var showAddFriend: Bool = false
    @State private var showRequestsInbox: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showBlocked: Bool = false
    @State private var showActivityFeed: Bool = false
    @State private var showGroupChallenges: Bool = false

    @State private var friendToChallenge: SocialProfileSummary? = nil
    @State private var friendToReport: SocialProfileSummary? = nil
    @State private var selectedChallenge: PopulatedChallenge? = nil
    @State private var selectedSegment: Int = 0

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerActions
                    pendingBanner
                    segmentControl
                    if selectedSegment == 0 {
                        friendsSection
                    } else {
                        challengesSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("friendsTitle", lang))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showNotifications = true
                        } label: {
                            // Surface unread badge in the menu label so users
                            // still know there are pending notifications.
                            if viewModel.unreadNotificationCount > 0 {
                                Label("\(L.t("notifications", lang)) (\(viewModel.unreadNotificationCount))",
                                       systemImage: "bell.badge.fill")
                            } else {
                                Label(L.t("notifications", lang), systemImage: "bell")
                            }
                        }
                        Divider()
                        Button {
                            showActivityFeed = true
                        } label: {
                            Label(L.t("activityFeed", lang), systemImage: "sparkles")
                        }
                        Button {
                            showGroupChallenges = true
                        } label: {
                            Label(L.t("groupChallenges", lang), systemImage: "person.3.fill")
                        }
                        Button {
                            showBlocked = true
                        } label: {
                            Label(L.t("blockedTitle", lang), systemImage: "hand.raised.slash")
                        }
                        Button {
                            showPrivacy = true
                        } label: {
                            Label(L.t("privacy", lang), systemImage: "lock.shield")
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .medium))
                            if viewModel.unreadNotificationCount > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 2, y: -1)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showRequestsInbox) {
                FriendRequestsInboxSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsInboxSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacySettingsSheet()
            }
            .sheet(isPresented: $showBlocked) {
                BlockListSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showActivityFeed) {
                NavigationStack {
                    ActivityFeedView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L.t("done", lang)) { showActivityFeed = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showGroupChallenges) {
                GroupChallengesSheet()
            }
            .sheet(item: $friendToChallenge) { friend in
                ChallengeSetupSheet(viewModel: viewModel, opponent: friend)
            }
            .sheet(item: $friendToReport) { user in
                ReportUserSheet(viewModel: viewModel, user: user)
            }
            .sheet(item: $selectedChallenge) { ch in
                ChallengeDetailSheet(viewModel: viewModel, challenge: ch)
            }
            .task {
                viewModel.attach(appState)
                await viewModel.refresh()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Top actions

    private var headerActions: some View {
        HStack(spacing: 10) {
            actionPill(label: L.t("addBtn", lang), icon: "person.badge.plus") { showAddFriend = true }
            actionPill(
                label: L.t("requestsBtn", lang) + (viewModel.incomingRequests.isEmpty ? "" : " (\(viewModel.incomingRequests.count))"),
                icon: "envelope.badge"
            ) { showRequestsInbox = true }
            actionPill(label: L.t("activityBtn", lang), icon: "sparkles") { showActivityFeed = true }
        }
    }

    private func actionPill(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.06))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pendingBanner: some View {
        if !viewModel.pendingIncomingChallenges.isEmpty {
            Button {
                if let first = viewModel.pendingIncomingChallenges.first {
                    selectedChallenge = first
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.orange)
                    Text(L.t("pendingChallengesFmt", lang).replacingOccurrences(of: "%@", with: "\(viewModel.pendingIncomingChallenges.count)"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var segmentControl: some View {
        Picker("Tab", selection: $selectedSegment) {
            Text(L.t("friendsSegFmt", lang).replacingOccurrences(of: "%@", with: "\(viewModel.friends.count)")).tag(0)
            Text(L.t("challengesSegFmt", lang).replacingOccurrences(of: "%@", with: "\(viewModel.activeChallenges.count)")).tag(1)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Friends list

    @ViewBuilder
    private var friendsSection: some View {
        if viewModel.friends.isEmpty {
            emptyFriends
        } else {
            VStack(spacing: 8) {
                ForEach(viewModel.friends) { friend in
                    friendRow(friend)
                }
            }
        }
    }

    private func friendRow(_ friend: SocialProfileSummary) -> some View {
        SocialProfileRow(profile: friend, trailing: AnyView(
            Menu {
                Button {
                    friendToChallenge = friend
                } label: {
                    Label(L.t("challengeMenu", lang), systemImage: "flag.fill")
                }
                Button(role: .destructive) {
                    Task { await viewModel.removeFriend(friend) }
                } label: {
                    Label(L.t("removeFriend", lang), systemImage: "person.crop.circle.badge.minus")
                }
                Button(role: .destructive) {
                    Task { await viewModel.block(friend) }
                } label: {
                    Label(L.t("blockUser", lang), systemImage: "hand.raised.slash")
                }
                Button(role: .destructive) {
                    friendToReport = friend
                } label: {
                    Label(L.t("reportUser", lang), systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        ))
        .padding(.horizontal, 12)
        .gradientCard(tint: .blue)
    }

    private var emptyFriends: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(L.t("noFriendsYet", lang))
                .font(.subheadline.weight(.semibold))
            Text(L.t("searchByUsername", lang))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showAddFriend = true
            } label: {
                Text(L.t("addAFriend", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.primary)
                    .clipShape(.capsule)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Challenges

    @ViewBuilder
    private var challengesSection: some View {
        if viewModel.activeChallenges.isEmpty && viewModel.completedChallenges.isEmpty {
            emptyChallenges
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.activeChallenges.isEmpty {
                    section(title: L.t("activeSection", lang))
                    VStack(spacing: 8) {
                        ForEach(viewModel.activeChallenges) { ch in
                            Button { selectedChallenge = ch } label: {
                                challengeRow(ch)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !viewModel.completedChallenges.isEmpty {
                    section(title: L.t("recentSection", lang))
                    VStack(spacing: 8) {
                        ForEach(viewModel.completedChallenges.prefix(10)) { ch in
                            Button { selectedChallenge = ch } label: {
                                challengeRow(ch)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func section(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    private func challengeRow(_ ch: PopulatedChallenge) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(challengeColor(ch.row.status).opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: challengeIcon(ch.row.status))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(challengeColor(ch.row.status))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ch.iAmChallenger ? "You vs @\(ch.otherUser.username)" : "@\(ch.otherUser.username) vs you")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text(categoryLabel(ch.row.category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText(ch))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(challengeOutcomeColor(ch))
                if let date = ch.row.completedAt ?? ch.row.respondedAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .gradientCard(tint: challengeOutcomeColor(ch))
    }

    /// Status color that distinguishes won (green) vs lost (red) on completed
    /// challenges — the base `challengeColor` paints both green which kills the
    /// signal in the list view.
    private func challengeOutcomeColor(_ ch: PopulatedChallenge) -> Color {
        if ch.row.status == "completed" {
            guard let me = appState.currentUserIdPublic else { return .green }
            return ch.row.winnerUserId == me ? .green : .red
        }
        return challengeColor(ch.row.status)
    }

    private func challengeIcon(_ status: String) -> String {
        switch status {
        case "pending":     return "hourglass"
        case "accepted", "in_progress": return "play.fill"
        case "completed":   return "trophy.fill"
        default:            return "flag.fill"
        }
    }

    private func challengeColor(_ status: String) -> Color {
        switch status {
        case "pending":     return .orange
        case "accepted", "in_progress": return .blue
        case "completed":   return .green
        default:            return .gray
        }
    }

    private func statusText(_ ch: PopulatedChallenge) -> String {
        switch ch.row.status {
        case "pending":     return L.t("statusPending", lang)
        case "accepted":    return L.t("statusAccepted", lang)
        case "in_progress": return L.t("statusInProgress", lang)
        case "completed":
            guard let me = appState.currentUserIdPublic else { return L.t("statusDoneShort", lang) }
            return ch.row.winnerUserId == me ? L.t("youWon", lang) : L.t("youLost", lang)
        case "declined":    return L.t("statusDeclined", lang)
        case "expired":     return L.t("statusExpired", lang)
        default:            return ch.row.status.capitalized
        }
    }

    private func categoryLabel(_ id: String) -> String {
        switch id {
        case "physique": return L.t("catPhysique", lang)
        case "workout_volume": return L.t("catVolume", lang)
        case "scan_score": return L.t("catScanScore", lang)
        case "streak": return L.t("catStreak", lang)
        default: return id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var emptyChallenges: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(L.t("noChallengesYet", lang))
                .font(.subheadline.weight(.semibold))
            Text(L.t("noChallengesDesc", lang))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
