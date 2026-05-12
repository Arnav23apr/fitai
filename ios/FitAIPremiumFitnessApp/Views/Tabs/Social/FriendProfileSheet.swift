import SwiftUI

/// Tap a friend bubble in the Compete tab → this sheet. Shows the friend's
/// identity (avatar, name, @handle, bio), summary stats, and the live
/// head-to-head record between us. Primary action is "Challenge."
///
/// We hold a Bindable reference to the parent FriendViewModel so the
/// "Challenge" button can route through the same kickoff path the rest of
/// Compete uses (no duplicate API surface).
struct FriendProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel
    let friend: SocialProfileSummary

    @State private var detail: FriendProfileDetail? = nil
    @State private var isLoading: Bool = true
    @State private var showChallengeOptions: Bool = false
    @State private var showPaywall: Bool = false
    /// Triggers the unified BattleSetupView in Friend mode with this
    /// friend pre-selected. Replaces the old "fire send_challenge
    /// immediately" path for physique battles so the user gets the same
    /// setup UI regardless of entry point.
    @State private var showBattleSetup: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var social: SocialService { SocialService.shared }

    /// Completed battles between the current user and this friend, used to
    /// compute the head-to-head record. Pulled from the view model so the
    /// number stays accurate after a fresh battle settles.
    private var completedHeadToHead: [PopulatedChallenge] {
        viewModel.challenges.filter {
            $0.row.status == "completed" && $0.otherUser.id == friend.id
        }
    }

    private var myWins: Int {
        guard let myId = appState.currentUserIdPublic else { return 0 }
        return completedHeadToHead.filter { $0.row.winnerUserId == myId }.count
    }
    private var theirWins: Int {
        completedHeadToHead.count - myWins
    }

    /// Overall record across ALL completed challenges the current user has
    /// played, regardless of opponent. Surfaced alongside the head-to-head
    /// number so the user can anchor their performance against this friend
    /// to their broader track record.
    private var overallCompleted: [PopulatedChallenge] {
        viewModel.challenges.filter { $0.row.status == "completed" }
    }
    private var overallWins: Int {
        guard let myId = appState.currentUserIdPublic else { return 0 }
        return overallCompleted.filter { $0.row.winnerUserId == myId }.count
    }
    private var overallLosses: Int {
        overallCompleted.count - overallWins
    }

    /// Single brand accent for the profile sheet. Tiers/ranks aren't
    /// shipping in v1 so we don't drive theming off them; orange is the
    /// existing Compete/Mog-Battle accent and feels consistent.
    private var accent: Color { .orange }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroCard
                    if let bio = (detail?.bio ?? "").nilIfEmpty {
                        bioCard(bio)
                    }
                    statsRow
                    headToHeadCard
                    actionsRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(
                // Whisper-quiet brand accent at the very top so the page
                // doesn't feel sterile, but nothing that competes with
                // the content.
                ZStack {
                    Color(.systemBackground)
                    LinearGradient(
                        colors: [accent.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadDetail() }
        }
        .confirmationDialog(
            "Start a 1v1",
            isPresented: $showChallengeOptions,
            titleVisibility: .visible
        ) {
            Button("Physique Battle") {
                // Open the unified BattleSetupView with this friend
                // pre-selected. The user picks their photo there and the
                // send/upload/analyze chain runs from BattleSetupView's
                // friend mode. Other categories below stay on the
                // immediate-send path since they're not photo-based.
                showBattleSetup = true
            }
            Button("Most Volume This Week") {
                Task { await sendChallenge(category: "workout_volume") }
            }
            Button("Longer Streak") {
                Task { await sendChallenge(category: "streak") }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showPaywall) { PaywallSheet(context: .battle) }
        .fullScreenCover(isPresented: $showBattleSetup) {
            BattleSetupView(preselectedFriend: friend)
        }
    }

    // MARK: - Hero (avatar + name + handle + tier)

    /// No-card centered identity. Soft accent halo around a compact avatar,
    /// name + handle stacked below. Streak (if any) appears as a quiet
    /// caption-sized fire glyph — no chip, no border.
    private var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 28,
                            endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle().strokeBorder(accent.opacity(0.35), lineWidth: 1)
                    )
                if let photoURL = detail?.profilePhotoURL ?? friend.profilePhotoURL,
                   let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Image(systemName: detail?.avatarSystemName
                                              ?? friend.avatarSystemName
                                              ?? "person.crop.circle.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                } else {
                    Image(systemName: detail?.avatarSystemName
                                      ?? friend.avatarSystemName
                                      ?? "person.crop.circle.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            }

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(detail?.displayName ?? friend.displayName)
                        .font(.title2.weight(.semibold))
                    if (detail?.isPremium ?? friend.isPremium) == true {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.00, green: 0.85, blue: 0.30),
                                        Color(red: 1.00, green: 0.62, blue: 0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.orange.opacity(0.45), radius: 4)
                            .accessibilityLabel("Pro member")
                    }
                }
                HStack(spacing: 6) {
                    Text("@\(detail?.username ?? friend.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let streak = detail?.currentStreak ?? friend.currentStreak, streak > 0 {
                        Text("·")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(streak)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bio

    private func bioCard(_ bio: String) -> some View {
        Text(bio)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile(
                value: detail?.latestScore.map { String(format: "%.1f", $0) } ?? "—",
                label: "Scan",
                icon: "camera.viewfinder",
                tint: .blue
            )
            statTile(
                value: "\(detail?.currentStreak ?? friend.currentStreak ?? 0)",
                label: "Streak",
                icon: "flame.fill",
                tint: .orange
            )
            statTile(
                value: "\(detail?.totalWorkouts ?? friend.totalWorkouts ?? 0)",
                label: "Workouts",
                icon: "dumbbell.fill",
                tint: .purple
            )
        }
    }

    /// Tinted Liquid Glass tile, same material treatment as the workout
    /// hero card on the Plan tab. The icon carries the only color; the
    /// card itself picks up the glass material + a soft accent stroke.
    private func statTile(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .liquidGlassCard(tint: tint, cornerRadius: 14)
    }

    // MARK: - Head-to-head

    private var headToHeadCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Head-to-head")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedHeadToHead.count) battle\(completedHeadToHead.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                wlBlock(label: "Wins", count: myWins, color: .green)
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 1, height: 40)
                wlBlock(label: "Losses", count: theirWins, color: .red)
            }

            // Continuous green→red fade with a thin tick marking the
            // user's actual win share. The tick anchors the gradient
            // to real data without breaking the smooth color flow.
            if !completedHeadToHead.isEmpty {
                winRateBar
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    /// Color distribution itself encodes the win rate. The green half
    /// runs from 0 → winShare, the red half from winShare → 1, with a
    /// short soft fade zone (±4% around the boundary) where the two
    /// colors blend. 0W-3L reads as nearly all red; 3W-3L as a clear
    /// 50/50 split with a tight midline.
    private var winRateBar: some View {
        let total = max(myWins + theirWins, 1)
        let winShare = Double(myWins) / Double(total)
        let fade: Double = 0.04
        let fadeStart = max(0.0, winShare - fade)
        let fadeEnd = min(1.0, winShare + fade)
        let green = Color(red: 0.20, green: 0.85, blue: 0.55)
        let red = Color(red: 0.95, green: 0.30, blue: 0.40)
        return Capsule()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: green, location: 0),
                        .init(color: green, location: fadeStart),
                        .init(color: red, location: fadeEnd),
                        .init(color: red, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 5)
            .opacity(0.9)
    }

    private func wlBlock(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var actionsRow: some View {
        VStack(spacing: 10) {
            Button {
                if appState.profile.canCreateChallenge {
                    showChallengeOptions = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Challenge @\(friend.username)")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .modifier(LiquidGlassButton(tint: accent))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: showChallengeOptions)

            Menu {
                Button(role: .destructive) {
                    Task {
                        await viewModel.removeFriend(friend)
                        dismiss()
                    }
                } label: {
                    Label("Remove friend", systemImage: "person.fill.xmark")
                }
                Button(role: .destructive) {
                    Task {
                        _ = await social.blockUser(otherUserId: friend.id)
                        await viewModel.refresh()
                        dismiss()
                    }
                } label: {
                    Label("Block", systemImage: "hand.raised.fill")
                }
            } label: {
                Text("More")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }

    // MARK: - Helpers

    private func loadDetail() async {
        isLoading = true
        detail = await social.fetchProfileDetail(userId: friend.id)
        isLoading = false
    }

    private func sendChallenge(category: String) async {
        await viewModel.sendChallenge(opponent: friend, category: category)
        await viewModel.refresh()
        dismiss()
    }

}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
