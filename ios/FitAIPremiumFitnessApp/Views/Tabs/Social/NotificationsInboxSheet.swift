import SwiftUI

/// Recent social events — incoming requests, accepts, challenges, results,
/// group challenge invites. Reads from the `notifications` server table
/// (populated by the various social RPCs).
struct NotificationsInboxSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No notifications yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Friend requests, challenges, and 1v1 results show up here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.notifications) { n in
                            notificationRow(n)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle(L.t("activity", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.unreadNotificationCount > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Mark all read") {
                            Task { await viewModel.markAllNotificationsRead() }
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                }
            }
        }
    }

    private func notificationRow(_ n: NotificationRow) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor(for: n.kind).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName(for: n.kind))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor(for: n.kind))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(message(for: n))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(n.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if !n.read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for kind: String) -> String {
        switch kind {
        case "friend_request_received": return "person.crop.circle.badge.plus"
        case "friend_request_accepted": return "checkmark.circle.fill"
        case "challenge_received":      return "flag.fill"
        case "challenge_accepted":      return "play.fill"
        case "challenge_declined":      return "xmark.circle.fill"
        case "challenge_completed":     return "trophy.fill"
        case "group_challenge_invited": return "person.3.fill"
        case "friend_workout_nudge":    return "flame.fill"
        default:                        return "bell.fill"
        }
    }

    private func iconColor(for kind: String) -> Color {
        switch kind {
        case "friend_request_received": return .blue
        case "friend_request_accepted": return .green
        case "challenge_received":      return .orange
        case "challenge_accepted":      return .blue
        case "challenge_declined":      return .red
        case "challenge_completed":     return .yellow
        case "group_challenge_invited": return .purple
        case "friend_workout_nudge":    return .orange
        default:                        return .gray
        }
    }

    private func message(for n: NotificationRow) -> String {
        switch n.kind {
        case "friend_request_received":  return "Someone sent you a friend request"
        case "friend_request_accepted":  return "Your friend request was accepted"
        case "challenge_received":       return "You've been challenged to a 1v1"
        case "challenge_accepted":       return "Your challenge was accepted"
        case "challenge_declined":       return "Your challenge was declined"
        case "challenge_completed":      return "Your 1v1 result is in"
        case "group_challenge_invited":  return "You were invited to a group challenge"
        case "friend_workout_nudge":     return "A friend just lifted — your turn?"
        default:                          return "New activity"
        }
    }
}
