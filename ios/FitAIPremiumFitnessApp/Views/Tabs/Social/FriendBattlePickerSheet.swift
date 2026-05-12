import SwiftUI

/// Friend picker presented from the top-right of BattleSetupView. Tapping a
/// friend pre-fills their name as the opponent so the user can run a local
/// AI photo battle against someone they know — without typing the name.
///
/// "Online" is rendered as a green dot whenever the friend has any recent
/// activity (currentStreak > 0). True realtime presence comes later; for now
/// the green dot is "has account and active" per the agreed semantics.
struct FriendBattlePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var friendVM: FriendViewModel
    var onPick: (SocialProfileSummary) -> Void

    /// Brand accent used for halos, online dot ring, and the soft top
    /// background wash. Matches the rest of the Compete surface.
    private var accent: Color { .red }

    var body: some View {
        NavigationStack {
            Group {
                if friendVM.friends.isEmpty {
                    emptyState
                } else {
                    friendList
                }
            }
            .background(
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
            .navigationTitle("Pick a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var listHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
            Text("Choose your opponent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(friendVM.friends.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }

    private var friendList: some View {
        ScrollView {
            VStack(spacing: 10) {
                listHeader
                ForEach(friendVM.friends) { friend in
                    friendRow(friend)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    private func friendRow(_ friend: SocialProfileSummary) -> some View {
        Button {
            onPick(friend)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    // Soft accent halo behind the avatar — same idiom as
                    // the profile sheet hero, smaller scale.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)

                    FriendAvatarView(
                        photoURL: friend.profilePhotoURL,
                        symbolName: friend.avatarSystemName,
                        size: 46,
                        symbolSize: 28,
                        fallbackBackground: Color.primary.opacity(0.06),
                        symbolColor: .secondary
                    )
                    .overlay(
                        Circle().strokeBorder(accent.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if friend.isOnline {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.25, green: 0.85, blue: 0.55),
                                            Color(red: 0.20, green: 0.72, blue: 0.78)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 11, height: 11)
                                .overlay(
                                    Circle().strokeBorder(Color(.systemBackground), lineWidth: 2)
                                )
                                .shadow(color: Color.green.opacity(0.45), radius: 3)
                                .offset(x: 1, y: 1)
                        }
                    }
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 5) {
                        Text("@\(friend.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let streak = friend.currentStreak, streak > 0 {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(streak)")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accent.opacity(0.18), Color.primary.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: friend.id)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 110, height: 110)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text("No friends yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Add friends from the Compete tab to battle them here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
