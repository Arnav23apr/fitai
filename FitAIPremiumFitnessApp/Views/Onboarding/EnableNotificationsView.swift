import SwiftUI
import UserNotifications

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        .frame(width: 100, height: 100)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.primary)
                        .symbolEffect(.bounce, value: appeared)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

                VStack(spacing: 12) {
                    Text(L.t("enableNotifications", lang))
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(L.t("notificationsSubtitle", lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 16) {
                    notificationRow(icon: "flame.fill", title: L.t("notifWorkoutReminders", lang), subtitle: L.t("notifWorkoutRemindersDesc", lang))
                    notificationRow(icon: "trophy.fill", title: L.t("notifAchievements", lang), subtitle: L.t("notifAchievementsDesc", lang))
                    notificationRow(icon: "person.2.fill", title: L.t("notifFriendActivity", lang), subtitle: L.t("notifFriendActivityDesc", lang))
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
            }

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button(action: requestNotifications) {
                    Text(L.t("enableNotifications", lang))
                        .font(.headline)
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(.rect(cornerRadius: 16))
                }

                Button(action: onContinue) {
                    Text(L.t("maybeLater", lang))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private func notificationRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            Task { @MainActor in
                onContinue()
            }
        }
    }
}
