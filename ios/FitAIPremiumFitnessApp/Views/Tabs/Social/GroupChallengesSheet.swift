import SwiftUI

@Observable
@MainActor
final class GroupChallengeViewModel {
    var challenges: [GroupChallengeRow] = []
    var creator: Bool = false
    var isLoading: Bool = false

    private let social = SocialService.shared

    func refresh(myUserId: String?) async {
        guard let me = myUserId else { return }
        isLoading = true
        defer { isLoading = false }
        challenges = await social.fetchGroupChallenges(myUserId: me)
    }

    func create(title: String, description: String, metric: String, target: Double, endsAt: Date) async -> Bool {
        let r = await social.createGroupChallenge(
            title: title, description: description, metric: metric, target: target, endsAt: endsAt
        )
        return r.ok
    }
}

/// List of group challenges + create button. Detail view shows the leaderboard.
struct GroupChallengesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var viewModel = GroupChallengeViewModel()
    @State private var showCreate: Bool = false
    @State private var selected: GroupChallengeRow? = nil

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.challenges.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.challenges) { ch in
                            Button { selected = ch } label: {
                                challengeRow(ch)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.refresh(myUserId: appState.currentUserIdPublic)
                    }
                }
            }
            .navigationTitle(L.t("groupChallenges", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("close", lang)) { dismiss() }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateGroupChallengeSheet { title, desc, metric, target, endsAt in
                    Task {
                        let ok = await viewModel.create(title: title, description: desc, metric: metric, target: target, endsAt: endsAt)
                        if ok {
                            await viewModel.refresh(myUserId: appState.currentUserIdPublic)
                        }
                    }
                }
            }
            .sheet(item: $selected) { ch in
                GroupChallengeDetailSheet(challenge: ch)
            }
            .task {
                await viewModel.refresh(myUserId: appState.currentUserIdPublic)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No group challenges")
                .font(.subheadline.weight(.semibold))
            Text("Create one and invite friends to compete on a metric over a week.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showCreate = true
            } label: {
                Text("Create one")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.primary)
                    .clipShape(.capsule)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func challengeRow(_ ch: GroupChallengeRow) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: metricIcon(ch.metric))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ch.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(timeRemaining(until: ch.endsAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private func metricIcon(_ metric: String) -> String {
        switch metric {
        case "scan_score":    return "sparkles"
        case "workout_count": return "checkmark.circle.fill"
        case "streak_days":   return "flame.fill"
        case "volume_kg":     return "dumbbell.fill"
        default:              return "trophy.fill"
        }
    }

    private func timeRemaining(until end: Date) -> String {
        let interval = end.timeIntervalSinceNow
        if interval <= 0 { return "Ended" }
        let days = Int(interval / 86400)
        if days > 0 { return "\(days) day\(days == 1 ? "" : "s") left" }
        let hours = Int(interval / 3600)
        return "\(hours) hour\(hours == 1 ? "" : "s") left"
    }
}

// MARK: - Create

struct CreateGroupChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (_ title: String, _ description: String, _ metric: String, _ target: Double, _ endsAt: Date) -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var metric: String = "workout_count"
    @State private var targetText: String = "5"
    @State private var endsAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. 5 workouts this week", text: $title)
                }
                Section("Description") {
                    TextField("Optional details", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Metric") {
                    Picker("Metric", selection: $metric) {
                        Text("Workouts completed").tag("workout_count")
                        Text("Highest scan score").tag("scan_score")
                        Text("Streak days").tag("streak_days")
                        Text("Volume (kg)").tag("volume_kg")
                    }
                    TextField("Target", text: $targetText)
                        .keyboardType(.decimalPad)
                }
                Section("Ends") {
                    DatePicker("End date", selection: $endsAt, in: Date()..., displayedComponents: .date)
                }
            }
            .navigationTitle("New challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let target = Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        onCreate(title, description, metric, target, endsAt)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Detail

struct GroupChallengeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let challenge: GroupChallengeRow

    @State private var members: [GroupChallengeMemberRow] = []
    @State private var profilesById: [String: SocialProfileSummary] = [:]
    @State private var isLoading: Bool = false

    private let social = SocialService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    leaderboardCard
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await load()
            }
            .refreshable {
                await load()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !challenge.description.isEmpty {
                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 14) {
                Label("Target: \(Int(challenge.target))", systemImage: "target")
                Label {
                    Text(challenge.endsAt, format: .dateTime.month().day())
                } icon: {
                    Image(systemName: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var leaderboardCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Leaderboard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.8) }
            }
            .padding(.bottom, 8)

            ForEach(Array(members.enumerated()), id: \.element.userId) { idx, m in
                memberRow(rank: idx + 1, member: m)
                if idx < members.count - 1 {
                    Divider()
                }
            }

            if members.isEmpty && !isLoading {
                Text("No participants yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
            }
        }
    }

    private func memberRow(rank: Int, member: GroupChallengeMemberRow) -> some View {
        let profile = profilesById[member.userId]
        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(rank <= 3 ? Color.yellow : Color.secondary)
                .frame(width: 24, alignment: .leading)
            if let profile {
                SocialProfileRow(profile: profile)
            } else {
                Text("…")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatScore(member.score, metric: challenge.metric))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }

    private func formatScore(_ s: Double, metric: String) -> String {
        switch metric {
        case "scan_score": return String(format: "%.1f", s)
        case "volume_kg":  return "\(Int(s))kg"
        default:           return "\(Int(s))"
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        members = await social.fetchGroupChallengeMembers(challengeId: challenge.id)
        let userIds = members.map(\.userId)
        profilesById = await social.fetchProfilesByIds(userIds)
    }
}
