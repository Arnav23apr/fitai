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
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.notifications) { n in
                                notificationRow(n)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(Color(.systemBackground))
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

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.indigo.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 110, height: 110)
                Image(systemName: "bell.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text("No notifications yet")
                .font(.subheadline.weight(.semibold))
            Text("Friend requests, challenges, and 1v1 results show up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func notificationRow(_ n: NotificationRow) -> some View {
        let gradient = iconGradient(for: n.kind)
        let isUnread = !n.read
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isUnread ? gradient : gradient.map { $0.opacity(0.45) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: gradient[0].opacity(isUnread ? 0.35 : 0.10), radius: 6, y: 2)
                Image(systemName: iconName(for: n.kind))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(message(for: n))
                    .font(.subheadline.weight(isUnread ? .semibold : .regular))
                    .foregroundStyle(isUnread ? .primary : .secondary)
                    .lineLimit(2)
                Text(n.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)

            if isUnread {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 8, height: 8)
                    .shadow(color: gradient[0].opacity(0.6), radius: 4)
            }
        }
        .padding(14)
        .liquidGlassCard(
            tint: gradient[0],
            cornerRadius: 14,
            isProminent: isUnread
        )
        .opacity(isUnread ? 1.0 : 0.78)
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

    /// Paired gradient per notification kind. Mirrors the palette used by
    /// the activity feed so the two surfaces feel like one system.
    private func iconGradient(for kind: String) -> [Color] {
        switch kind {
        case "friend_request_received":
            return [Color(red: 0.30, green: 0.55, blue: 1.00), Color(red: 0.45, green: 0.35, blue: 0.95)]
        case "friend_request_accepted":
            return [Color(red: 0.25, green: 0.85, blue: 0.55), Color(red: 0.20, green: 0.72, blue: 0.78)]
        case "challenge_received":
            return [Color(red: 1.00, green: 0.50, blue: 0.30), Color(red: 0.96, green: 0.30, blue: 0.45)]
        case "challenge_accepted":
            return [Color(red: 0.30, green: 0.65, blue: 1.00), Color(red: 0.20, green: 0.85, blue: 0.95)]
        case "challenge_declined":
            return [Color(red: 0.95, green: 0.30, blue: 0.40), Color(red: 0.85, green: 0.20, blue: 0.55)]
        case "challenge_completed":
            return [Color(red: 1.00, green: 0.80, blue: 0.25), Color(red: 1.00, green: 0.55, blue: 0.20)]
        case "group_challenge_invited":
            return [Color(red: 0.55, green: 0.40, blue: 0.95), Color(red: 0.80, green: 0.35, blue: 0.95)]
        case "friend_workout_nudge":
            return [Color(red: 1.00, green: 0.62, blue: 0.20), Color(red: 1.00, green: 0.36, blue: 0.18)]
        default:
            return [Color.gray.opacity(0.75), Color.gray.opacity(0.55)]
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
