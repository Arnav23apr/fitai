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
    private struct Category: Identifiable {
        let id: String
        let label: String
        let tagline: String
        let icon: String
        let gradient: [Color]
    }

    private let categories: [Category] = [
        Category(id: "physique", label: "Physique Battle", tagline: "AI-judged head-to-head", icon: "figure.arms.open", gradient: [Color(red: 1.00, green: 0.34, blue: 0.40), Color(red: 0.96, green: 0.18, blue: 0.55)]),
        Category(id: "workout_volume", label: "Most Volume This Week", tagline: "Highest kg lifted wins", icon: "dumbbell.fill", gradient: [Color(red: 0.34, green: 0.55, blue: 1.00), Color(red: 0.45, green: 0.30, blue: 0.95)]),
        Category(id: "streak", label: "Longer Streak", tagline: "Don't break the chain", icon: "flame.fill", gradient: [Color(red: 1.00, green: 0.62, blue: 0.20), Color(red: 1.00, green: 0.36, blue: 0.18)])
    ]

    private var selectedGradient: [Color] {
        categories.first { $0.id == selectedCategory }?.gradient
            ?? [Color.primary, Color.primary]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGlow
                    .ignoresSafeArea()

                VStack(spacing: 22) {
                    opponentCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .padding(.leading, 4)
                        VStack(spacing: 10) {
                            ForEach(categories) { cat in
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
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(appState.profile.canCreateChallenge ? "Send challenge" : "Unlock to send")
                                .font(.headline)
                        }
                        .foregroundStyle(appState.profile.canCreateChallenge ? .white : Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background {
                            if appState.profile.canCreateChallenge {
                                LinearGradient(
                                    colors: selectedGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.primary
                            }
                        }
                        .clipShape(.rect(cornerRadius: 26))
                        .shadow(
                            color: appState.profile.canCreateChallenge
                                ? selectedGradient.first?.opacity(0.35) ?? .clear
                                : .clear,
                            radius: 16, x: 0, y: 6
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .animation(.snappy(duration: 0.3), value: selectedCategory)
                }
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

    /// Soft radial wash in the selected category's accent color. Sits behind
    /// the content and animates as the user changes selection.
    private var backgroundGlow: some View {
        RadialGradient(
            colors: [
                (selectedGradient.first ?? .clear).opacity(0.18),
                Color.clear
            ],
            center: .top,
            startRadius: 0,
            endRadius: 380
        )
        .animation(.easeInOut(duration: 0.45), value: selectedCategory)
    }

    private var opponentCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .secondary.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                Text("VS")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: selectedGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(3)
                Rectangle()
                    .fill(LinearGradient(colors: [.secondary.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .padding(.horizontal, 60)

            SocialProfileRow(profile: opponent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.primary.opacity(0.04))
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: selectedGradient.map { $0.opacity(0.35) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
        }
        .animation(.easeInOut(duration: 0.35), value: selectedCategory)
    }

    private func categoryRow(_ cat: Category) -> some View {
        let isSelected = selectedCategory == cat.id
        return Button {
            selectedCategory = cat.id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: isSelected ? cat.gradient : cat.gradient.map { $0.opacity(0.18) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: cat.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? .white : cat.gradient[0])
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(cat.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(cat.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: cat.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(isSelected ? 0.06 : 0.03))
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: cat.gradient.map { $0.opacity(0.08) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: cat.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
                }
            )
            .shadow(
                color: isSelected ? cat.gradient[0].opacity(0.22) : .clear,
                radius: 12, x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
