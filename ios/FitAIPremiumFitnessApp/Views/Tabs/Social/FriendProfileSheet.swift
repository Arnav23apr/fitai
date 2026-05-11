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
                VStack(spacing: 24) {
                    heroCard
                    if let bio = (detail?.bio ?? "").nilIfEmpty {
                        bioCard(bio)
                    }
                    statsRow
                    headToHeadCard
                    actionsRow
                }
                .padding(20)
            }
            .background(
                // Editorial vertical wash — subtle tier accent at the top
                // fades into systemBackground. Just enough color to feel
                // alive without breaking the monochrome brand.
                ZStack {
                    Color(.systemBackground)
                    LinearGradient(
                        colors: [
                            accent.opacity(0.16),
                            accent.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    RadialGradient(
                        colors: [accent.opacity(0.10), .clear],
                        center: .topTrailing,
                        startRadius: 40,
                        endRadius: 320
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
                Task { await sendChallenge(category: "physique") }
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
    }

    // MARK: - Hero (avatar + name + handle + tier)

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer halo — soft radial glow in brand accent
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.36), accent.opacity(0.0)],
                            center: .center,
                            startRadius: 36,
                            endRadius: 84
                        )
                    )
                    .frame(width: 148, height: 148)
                // Inner avatar disc — gradient fill + thin accent ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.30), accent.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 102, height: 102)
                    .overlay(
                        Circle()
                            .strokeBorder(accent.opacity(0.50), lineWidth: 2)
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
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                    }
                    .frame(width: 102, height: 102)
                    .clipShape(Circle())
                } else {
                    Image(systemName: detail?.avatarSystemName
                                      ?? friend.avatarSystemName
                                      ?? "person.crop.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.85))
                }
            }
            VStack(spacing: 4) {
                Text(detail?.displayName ?? friend.displayName)
                    .font(.title2.weight(.bold))
                Text("@\(detail?.username ?? friend.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bio

    private func bioCard(_ bio: String) -> some View {
        Text(bio)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.primary.opacity(0.04))
            .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(
                value: detail?.latestScore.map { String(format: "%.1f", $0) } ?? "—",
                label: "SCAN"
            )
            statTile(
                value: "\(detail?.currentStreak ?? friend.currentStreak ?? 0)",
                label: "STREAK"
            )
            statTile(
                value: "\(detail?.totalWorkouts ?? friend.totalWorkouts ?? 0)",
                label: "WORKOUTS"
            )
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Head-to-head

    private var headToHeadCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("HEAD-TO-HEAD")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedHeadToHead.count) battle\(completedHeadToHead.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                wlBlock(label: "WINS", count: myWins, color: .green)
                wlDivider
                wlBlock(label: "LOSSES", count: theirWins, color: .red)
            }

            Divider().opacity(0.2)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("OVERALL RECORD")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 6) {
                        Text("\(overallWins)")
                            .font(.callout.weight(.heavy))
                            .foregroundStyle(.green)
                        Text("–")
                            .font(.callout.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text("\(overallLosses)")
                            .font(.callout.weight(.heavy))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(0.12),
                    Color.primary.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func wlBlock(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var wlDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 44)
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
                    Text("Challenge @\(friend.username)")
                }
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    // Subtle vertical gradient gives the button depth
                    // without colored CTA energy — stays editorial.
                    LinearGradient(
                        colors: [Color.primary, Color.primary.opacity(0.84)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: Color.primary.opacity(0.20), radius: 12, y: 4)
            }

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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
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
