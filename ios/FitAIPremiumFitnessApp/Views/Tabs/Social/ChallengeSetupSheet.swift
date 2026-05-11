import SwiftUI

/// Pick a category and send a 1v1 challenge to a friend. Replaces the previous
/// fake auto-accept flow with a real server-backed challenge.
struct ChallengeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel
    let opponent: SocialProfileSummary

    @State private var selectedCategory: String = "physique"
    @State private var showPaywall: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    /// Note: "Scan Score" was removed because Physique Battle uses scan
    /// scoring under the hood — they were the same battle with different
    /// labels.
    private let categories: [(id: String, label: String, icon: String)] = [
        ("physique", "Physique Battle", "figure.arms.open"),
        ("workout_volume", "Most Volume This Week", "dumbbell.fill"),
        ("streak", "Longer Streak", "flame.fill")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                opponentCard
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.leading, 4)
                    VStack(spacing: 8) {
                        ForEach(categories, id: \.id) { cat in
                            categoryRow(cat)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    if appState.profile.canCreateChallenge {
                        Task {
                            await viewModel.sendChallenge(opponent: opponent, category: selectedCategory)
                            dismiss()
                        }
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        if !appState.profile.canCreateChallenge {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(appState.profile.canCreateChallenge ? "Send challenge" : "Unlock to send")
                            .font(.headline)
                    }
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .clipShape(.rect(cornerRadius: 26))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle(L.t("challengeMenu", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallSheet(context: .battle) }
        }
    }

    private var opponentCard: some View {
        VStack(spacing: 12) {
            Text("VS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(2)
            SocialProfileRow(profile: opponent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(.rect(cornerRadius: 14))
        }
    }

    private func categoryRow(_ cat: (id: String, label: String, icon: String)) -> some View {
        let isSelected = selectedCategory == cat.id
        return Button {
            selectedCategory = cat.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cat.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .frame(width: 28)
                Text(cat.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(14)
            .background(isSelected ? Color.primary.opacity(0.07) : Color.primary.opacity(0.03))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
