import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var viewModel = FriendViewModel()
    @State private var activityVM = ActivityFeedViewModel()

    @State private var showAddFriend: Bool = false
    @State private var showRequestsInbox: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showBlocked: Bool = false
    @State private var showActivityFeed: Bool = false
    @State private var showGroupChallenges: Bool = false
    /// Friend picker presented from the Challenges tab "+ New Challenge" CTA.
    /// Tapping a friend hands off to ChallengeSetupSheet for that opponent.
    @State private var showFriendPickerForNew: Bool = false

    @State private var friendToChallenge: SocialProfileSummary? = nil
    @State private var friendToReport: SocialProfileSummary? = nil
    /// Tapping the profile area of a friend card opens FriendProfileSheet
    /// for that friend (head-to-head record, recent activity, profile photo).
    @State private var profileFriend: SocialProfileSummary? = nil
    @State private var selectedChallenge: PopulatedChallenge? = nil
    @State private var selectedSegment: Int = 0

    /// Live filter applied to the friends list. Matches against displayName
    /// and username substring, case-insensitive. Empty string → show all.
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    /// Background task that polls `viewModel.refresh()` every ~25s while
    /// the sheet is visible. Gives the Challenges tab a "near-realtime"
    /// feel without WebSockets — new challenges, accept/decline status,
    /// and submitted scores show up automatically within ~25s instead of
    /// waiting on a pull-to-refresh. Mirrors `startLeaderboardAutoRefresh`
    /// in CompeteView. Cancelled on .onDisappear.
    @State private var pollTask: Task<Void, Never>? = nil

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    pendingBanner
                    pillSegment

                    if selectedSegment == 0 {
                        headerActions
                        if !viewModel.friends.isEmpty {
                            friendsSearchBar
                        }
                        friendsSection
                        if !viewModel.friends.isEmpty {
                            inlineActivitySection
                        }
                    } else {
                        newChallengeCTA
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
            .sheet(isPresented: $showFriendPickerForNew) {
                FriendBattlePickerSheet(friendVM: viewModel) { friend in
                    showFriendPickerForNew = false
                    // Small delay so the picker dismiss animation finishes
                    // before ChallengeSetupSheet presents (avoids a flicker).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        friendToChallenge = friend
                    }
                }
            }
            .sheet(item: $friendToChallenge) { friend in
                ChallengeSetupSheet(viewModel: viewModel, opponent: friend)
            }
            .sheet(item: $friendToReport) { user in
                ReportUserSheet(viewModel: viewModel, user: user)
            }
            .sheet(item: $profileFriend) { friend in
                FriendProfileSheet(viewModel: viewModel, friend: friend)
            }
            .sheet(item: $selectedChallenge) { ch in
                ChallengeDetailSheet(viewModel: viewModel, challenge: ch)
            }
            .overlay(alignment: .top) { transientToast }
            .task {
                viewModel.attach(appState)
                await viewModel.refresh()
                // Inline activity preview — top items only, fetched on appear.
                // ActivityFeedView (full sheet) maintains its own VM, so a
                // refresh here doesn't conflict.
                if activityVM.events.isEmpty {
                    await activityVM.refresh()
                }
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .refreshable {
                await viewModel.refresh()
                await activityVM.refresh()
            }
        }
    }

    // MARK: - Header actions (Friends tab)

    private var headerActions: some View {
        HStack(spacing: 10) {
            actionPill(label: L.t("addBtn", lang), icon: "person.badge.plus") { showAddFriend = true }
            actionPill(
                label: L.t("requestsBtn", lang) + (viewModel.incomingRequests.isEmpty ? "" : " (\(viewModel.incomingRequests.count))"),
                icon: "envelope.badge"
            ) { showRequestsInbox = true }
            invitePill
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

    /// Invite uses ShareLink so the user can pick any system share target
    /// (iMessage, WhatsApp, mail, copy link). Same referral URL pattern as
    /// the paywall earn-free-scan flow.
    private var invitePill: some View {
        ShareLink(item: inviteURL, message: Text(L.t("inviteFriendsMessage", lang))) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                Text(L.t("inviteBtn", lang))
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

    private var inviteURL: URL {
        let code = appState.profile.referralCode
        let base = "https://apps.apple.com/app/id6744284188"
        return URL(string: code.isEmpty ? base : "\(base)?ref=\(code)")!
    }

    // MARK: - Pending banner

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

    // MARK: - Segment

    /// Matches the Plan/Templates control in PlanView — stock SwiftUI
    /// `.pickerStyle(.segmented)`. On iOS 26 this automatically picks up
    /// the system Liquid Glass treatment with no custom code; on older
    /// iOS it falls back to UIKit's UISegmentedControl. Keeps the look
    /// consistent across the two tabs that use this pattern.
    private var pillSegment: some View {
        Picker("Friends section", selection: Binding(
            get: { selectedSegment },
            set: { newValue in
                withAnimation(.snappy(duration: 0.22)) { selectedSegment = newValue }
            }
        )) {
            Text(L.t("friendsSegFmt", lang).replacingOccurrences(of: "%@", with: "\(viewModel.friends.count)"))
                .tag(0)
            Text(L.t("challengesSegFmt", lang).replacingOccurrences(of: "%@", with: "\(viewModel.activeChallenges.count)"))
                .tag(1)
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: selectedSegment)
    }

    // MARK: - Friends list

    /// Case-insensitive substring match against displayName + username.
    /// Trimming whitespace so a stray leading space doesn't kill all
    /// results.
    private var filteredFriends: [SocialProfileSummary] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.friends }
        return viewModel.friends.filter {
            $0.displayName.lowercased().contains(q) || $0.username.lowercased().contains(q)
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        if viewModel.friends.isEmpty {
            emptyFriends
        } else if filteredFriends.isEmpty {
            searchNoResults
        } else {
            VStack(spacing: 10) {
                ForEach(filteredFriends) { friend in
                    friendCard(friend)
                }
            }
        }
    }

    // MARK: - Search bar

    /// Apple-style "liquid glass" search field. Uses `glassEffect` on
    /// iOS 26+; falls back to `.ultraThinMaterial` underneath the same
    /// capsule shape so older builds keep visual continuity with the
    /// pill segment + action buttons above it.
    private var friendsSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search friends", text: $searchText)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.subheadline)
                .submitLabel(.search)
                .tint(.primary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .modifier(LiquidGlassCapsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    searchFocused
                        ? Color.primary.opacity(0.20)
                        : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
        )
        .animation(.snappy(duration: 0.18), value: searchText.isEmpty)
        .animation(.snappy(duration: 0.18), value: searchFocused)
    }

    private var searchNoResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No friends match \u{201C}\(searchText)\u{201D}")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button {
                searchText = ""
                searchFocused = false
            } label: {
                Text("Clear search")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private func friendCard(_ friend: SocialProfileSummary) -> some View {
        let h2h = viewModel.headToHead(with: friend)
        let tint = friendCardTint(wins: h2h.wins, losses: h2h.losses)
        return VStack(spacing: 12) {
            // Top: profile row + H2H pill — tappable to open FriendProfileSheet.
            // Keep this as its own button so the Hype/Battle/menu controls below
            // retain their own hit areas.
            Button {
                profileFriend = friend
            } label: {
                SocialProfileRow(
                    profile: friend,
                    trailing: AnyView(headToHeadPill(wins: h2h.wins, losses: h2h.losses))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: profileFriend?.id == friend.id)

            // Action row: Battle on the left, ellipsis menu on the right.
            // Battle is the high-stakes path that opens ChallengeSetupSheet.
            HStack(spacing: 8) {
                battleButton(friend)
                Spacer()
                rowMenu(friend)
            }
        }
        .padding(14)
        .liquidGlassCard(tint: tint, cornerRadius: 18)
    }

    /// Transient toast surfaced from the view model's success/error messages
    /// (hype, friend request, block, etc). Auto-clears via the view model's
    /// `clearTransientMessagesSoon` after ~2.5s.
    @ViewBuilder
    private var transientToast: some View {
        if let msg = viewModel.successMessage ?? viewModel.lastError {
            let isError = viewModel.successMessage == nil
            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isError
                                ? [Color(red: 0.95, green: 0.30, blue: 0.40), Color(red: 0.85, green: 0.20, blue: 0.55)]
                                : [Color(red: 1.00, green: 0.62, blue: 0.20), Color(red: 1.00, green: 0.36, blue: 0.18)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.snappy(duration: 0.35), value: msg)
        }
    }

    /// H2H-driven accent for the friend card. Winning → green, losing →
    /// red, even/no battles → indigo (neutral). Subtle enough that we
    /// don't punish the user visually for losing.
    private func friendCardTint(wins: Int, losses: Int) -> Color {
        if wins == 0 && losses == 0 { return .indigo }
        if wins > losses { return .green }
        if losses > wins { return .red }
        return .indigo
    }

    @ViewBuilder
    private func headToHeadPill(wins: Int, losses: Int) -> some View {
        if wins == 0 && losses == 0 {
            EmptyView()
        } else {
            let leading: Color = wins > losses ? .green : (losses > wins ? .red : .secondary)
            HStack(spacing: 0) {
                Text("\(wins)W")
                    .foregroundStyle(.green)
                Text("–")
                    .foregroundStyle(.tertiary)
                Text("\(losses)L")
                    .foregroundStyle(.red.opacity(0.9))
            }
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [leading.opacity(0.18), leading.opacity(0.06)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Capsule()
                        .strokeBorder(leading.opacity(0.35), lineWidth: 0.6)
                }
            )
        }
    }

    private func battleButton(_ friend: SocialProfileSummary) -> some View {
        Button {
            friendToChallenge = friend
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11, weight: .heavy))
                Text(L.t("battleBtn", lang))
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(colors: [.red, .red.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: friendToChallenge?.id == friend.id)
    }

    private func rowMenu(_ friend: SocialProfileSummary) -> some View {
        Menu {
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
                .frame(width: 32, height: 32)
        }
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

    // MARK: - Inline activity preview

    @ViewBuilder
    private var inlineActivitySection: some View {
        let preview = Array(activityVM.events.prefix(3))
        if !preview.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L.t("recentActivityTitle", lang))
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showActivityFeed = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(L.t("seeAll", lang))
                                .font(.caption2.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 8) {
                    ForEach(preview) { event in
                        activityPreviewRow(event)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func activityPreviewRow(_ event: ActivityEventRow) -> some View {
        let profile = activityVM.profilesById[event.userId]
        let gradient = activityGradient(event.kind)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: gradient[0].opacity(0.35), radius: 6, y: 2)
                Image(systemName: activityIcon(event.kind))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activityTitle(event, profile: profile))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(compactRelative(event.createdAt) + " ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(12)
        .liquidGlassCard(tint: gradient[0], cornerRadius: 14)
    }

    // Inlined copies of the ActivityFeedView event formatters. Tiny duplication
    // is cheaper than threading a shared helper across two view files.
    private func activityTitle(_ event: ActivityEventRow, profile: SocialProfileSummary?) -> String {
        let name = profile.map { "@\($0.username)" } ?? "Someone"
        switch event.kind {
        case "scan_completed":
            if let score = event.payload["score"]?.doubleValue {
                return "\(name) scanned · \(String(format: "%.1f", score))/10"
            }
            return "\(name) completed a scan"
        case "pr_set":
            let exercise = event.payload["exercise"]?.stringValue ?? "an exercise"
            if let weight = event.payload["weight"]?.doubleValue,
               let reps = event.payload["reps"]?.intValue {
                return "\(name) hit a PR · \(exercise) \(Int(weight))kg × \(reps)"
            }
            return "\(name) hit a new PR"
        case "streak_milestone":
            let days = event.payload["days"]?.intValue ?? 0
            return "\(name) is on a \(days)-day streak"
        case "challenge_won":
            let opp = event.payload["opponent"]?.stringValue ?? "someone"
            return "\(name) won a 1v1 against @\(opp)"
        case "workout_completed":
            let workout = event.payload["workout"]?.stringValue ?? "a workout"
            return "\(name) completed \(workout)"
        default:
            return "\(name) had activity"
        }
    }

    private func activityIcon(_ kind: String) -> String {
        switch kind {
        case "scan_completed":     return "camera.viewfinder"
        case "pr_set":             return "trophy.fill"
        case "streak_milestone":   return "flame.fill"
        case "challenge_won":      return "flag.checkered"
        case "workout_completed":  return "dumbbell.fill"
        default:                   return "sparkles"
        }
    }

    private func activityColor(_ kind: String) -> Color {
        switch kind {
        case "scan_completed":    return .blue
        case "pr_set":            return .yellow
        case "streak_milestone":  return .orange
        case "challenge_won":     return .green
        case "workout_completed": return .purple
        default:                  return .gray
        }
    }

    /// Paired gradient per activity kind. Mirrors `activityColor` for the
    /// dominant tint but adds a second stop so the icon chip and the
    /// surrounding glass card share one cohesive palette.
    private func activityGradient(_ kind: String) -> [Color] {
        switch kind {
        case "scan_completed":
            return [Color(red: 0.30, green: 0.65, blue: 1.00), Color(red: 0.20, green: 0.85, blue: 0.95)]
        case "pr_set":
            return [Color(red: 1.00, green: 0.80, blue: 0.25), Color(red: 1.00, green: 0.55, blue: 0.20)]
        case "streak_milestone":
            return [Color(red: 1.00, green: 0.62, blue: 0.20), Color(red: 1.00, green: 0.36, blue: 0.18)]
        case "challenge_won":
            return [Color(red: 0.25, green: 0.85, blue: 0.55), Color(red: 0.20, green: 0.72, blue: 0.78)]
        case "workout_completed":
            return [Color(red: 0.55, green: 0.40, blue: 0.95), Color(red: 0.80, green: 0.35, blue: 0.95)]
        default:
            return [Color.gray.opacity(0.7), Color.gray.opacity(0.5)]
        }
    }

    // MARK: - Challenges tab

    private var newChallengeCTA: some View {
        Button {
            showFriendPickerForNew = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text(L.t("newChallengeBtn", lang))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.red, .red.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showFriendPickerForNew)
    }

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
        let outcomeColor = challengeOutcomeColor(ch)
        let turn = viewModel.turn(for: ch)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(outcomeColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: challengeIcon(ch.row.status, won: turn == nil ? challengeWon(ch) : nil))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(outcomeColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(ch.iAmChallenger ? "You vs @\(ch.otherUser.username)" : "@\(ch.otherUser.username) vs you")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(categoryLabel(ch.row.category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let turn {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        turnBadge(turn: turn, opponentUsername: ch.otherUser.username)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText(ch))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(outcomeColor)
                if let date = ch.row.completedAt ?? ch.row.respondedAt {
                    Text(compactRelative(date) + (ch.row.status == "completed" ? " ago" : ""))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .gradientCard(tint: outcomeColor)
    }

    @ViewBuilder
    private func turnBadge(turn: FriendViewModel.ChallengeTurn, opponentUsername: String) -> some View {
        switch turn {
        case .mine:
            HStack(spacing: 3) {
                Circle().fill(.orange).frame(width: 6, height: 6)
                Text(L.t("yourTurnLabel", lang))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            }
        case .theirs:
            Text(L.t("waitingForFmt", lang).replacingOccurrences(of: "%@", with: opponentUsername))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        case .both:
            EmptyView()
        }
    }

    private func challengeOutcomeColor(_ ch: PopulatedChallenge) -> Color {
        if ch.row.status == "completed" {
            guard let me = appState.currentUserIdPublic else { return .green }
            return ch.row.winnerUserId == me ? .green : .red
        }
        return challengeColor(ch.row.status)
    }

    private func challengeWon(_ ch: PopulatedChallenge) -> Bool? {
        guard ch.row.status == "completed",
              let me = appState.currentUserIdPublic,
              let winner = ch.row.winnerUserId else { return nil }
        return winner == me
    }

    /// Trophy color now varies by outcome — gold trophy for wins, gray for
    /// losses. Active challenges still use the status icon.
    private func challengeIcon(_ status: String, won: Bool?) -> String {
        switch status {
        case "pending":     return "hourglass"
        case "accepted", "in_progress": return "play.fill"
        case "completed":   return won == true ? "trophy.fill" : "flag.checkered"
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

    // MARK: - Compact relative time

    // MARK: - Auto-refresh

    /// Polling alternative to Realtime WebSocket. Refetches challenges,
    /// friend requests, and notifications every 25s while the sheet is
    /// visible. Costs one HTTP request per cycle — negligible — and gives
    /// "near-realtime" UX without the WebSocket reconnect/quota complexity.
    /// Idempotent: cancels any prior task before starting a new one.
    private func startAutoRefresh() {
        stopAutoRefresh()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                if Task.isCancelled { return }
                await viewModel.refresh()
            }
        }
    }

    private func stopAutoRefresh() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Compact relative time

    /// Twitter-style abbreviated duration. Used everywhere the original code
    /// rendered `Text(date, style: .relative)` — that formatter produced
    /// "12 mins, 38 secs" which reads like a server log. This produces
    /// "12m" / "3h" / "5d" / "2w".
    private func compactRelative(_ date: Date) -> String {
        let delta = abs(Date().timeIntervalSince(date))
        let s = Int(delta)
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        if h < 24 { return "\(h)h" }
        let d = h / 24
        if d < 7 { return "\(d)d" }
        return "\(d / 7)w"
    }
}

/// Apple "liquid glass" capsule background. On iOS 26+ uses the real
/// `glassEffect` material so the search field reads as a translucent
/// chip floating over the page; on older OS versions falls back to
/// `.ultraThinMaterial` inside a Capsule shape, which preserves the same
/// visual rhythm without the live refraction.
private struct LiquidGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(Capsule().fill(.ultraThinMaterial))
        }
    }
}
