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
                List {
                    ForEach(viewModel.events) { event in
                        eventRow(event)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationTitle(L.t("activity", lang))
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.events.isEmpty {
                await viewModel.refresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
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
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(eventColor(event.kind).opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: eventIcon(event.kind))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(eventColor(event.kind))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(eventTitle(event, profile: profile))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(event.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
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
}
