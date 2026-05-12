import SwiftUI

/// Read-only feed of recent events from the user and their friends.
/// Fetches from `activity_events` (RLS handles visibility based on
/// friendship + privacy_mode).
@Observable
@MainActor
final class ActivityFeedViewModel {
    var events: [ActivityEventRow] = []
    var profilesById: [String: SocialProfileSummary] = [:]
    var isLoading: Bool = false

    private let social = SocialService.shared

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let rows = await social.fetchActivityFeed(limit: 100)
        let userIds = Array(Set(rows.map(\.userId)))
        let profiles = await social.fetchProfilesByIds(userIds)
        events = rows
        profilesById = profiles
    }
}

struct ActivityFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ActivityFeedViewModel()

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        Group {
            if viewModel.events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.events) { event in
                            eventRow(event)
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
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.events.isEmpty {
                await viewModel.refresh()
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
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text("No activity yet")
                .font(.subheadline.weight(.semibold))
            Text("Friends' scans, PRs, and 1v1 wins show up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func eventRow(_ event: ActivityEventRow) -> some View {
        let profile = viewModel.profilesById[event.userId]
        let gradient = eventGradient(event.kind)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: gradient[0].opacity(0.35), radius: 6, y: 2)
                Image(systemName: eventIcon(event.kind))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(eventTitle(event, profile: profile))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(event.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
        }
        .padding(14)
        .liquidGlassCard(tint: gradient[0], cornerRadius: 14)
    }

    private func eventTitle(_ event: ActivityEventRow, profile: SocialProfileSummary?) -> String {
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

    private func eventIcon(_ kind: String) -> String {
        switch kind {
        case "scan_completed":     return "camera.viewfinder"
        case "pr_set":             return "trophy.fill"
        case "streak_milestone":   return "flame.fill"
        case "challenge_won":      return "flag.checkered"
        case "workout_completed":  return "dumbbell.fill"
        default:                   return "sparkles"
        }
    }

    private func eventColor(_ kind: String) -> Color {
        switch kind {
        case "scan_completed":    return .blue
        case "pr_set":            return .yellow
        case "streak_milestone":  return .orange
        case "challenge_won":     return .green
        case "workout_completed": return .purple
        default:                  return .gray
        }
    }

    /// Paired gradient per event kind — mirrors the palette used in the
    /// notifications inbox and the Friends-tab inline activity preview
    /// so all three surfaces feel like one system.
    private func eventGradient(_ kind: String) -> [Color] {
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
            return [Color.gray.opacity(0.75), Color.gray.opacity(0.55)]
        }
    }
}
