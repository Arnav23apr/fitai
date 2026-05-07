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

    var body: some View {
        NavigationStack {
            Group {
                if friendVM.friends.isEmpty {
                    emptyState
                } else {
                    friendList
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Pick a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var friendList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(friendVM.friends) { friend in
                    Button {
                        onPick(friend)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                FriendAvatarView(
                                    photoURL: friend.profilePhotoURL,
                                    symbolName: friend.avatarSystemName,
                                    size: 44,
                                    symbolSize: 28,
                                    fallbackBackground: Color.primary.opacity(0.06),
                                    symbolColor: .secondary
                                )
                                if friend.isOnline {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                        .overlay(
                                            Circle().strokeBorder(Color(.systemBackground), lineWidth: 2)
                                        )
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
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
