import SwiftUI

struct CurrentPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private let features: [(icon: String, title: String)] = [
        ("figure.run", "AI Workout Plans"),
        ("camera.viewfinder", "Unlimited Body Scans"),
        ("chart.line.uptrend.xyaxis", "Progress Analytics"),
        ("trophy.fill", "Compete & Leaderboards"),
        ("bolt.fill", "Priority AI Coach"),
        ("sparkles", "All Future Features")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    badgeSection
                    planCard
                    featuresGrid
                    manageSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("subscription", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var badgeSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.25), .orange.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 4) {
                Text("FitAI Pro")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text(L.t("activePlan", lang))
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }
        }
        .padding(.top, 12)
    }

    private var planCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("currentPlan", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("Pro " + L.t("membership", lang))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("PRO")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 8))
            }

            Divider()

            HStack(spacing: 24) {
                planDetail(label: L.t("status", lang), value: L.t("active", lang), color: .green)
                planDetail(label: L.t("workouts", lang), value: "\(appState.profile.totalWorkouts)", color: .blue)
                planDetail(label: L.t("scans", lang), value: "\(appState.profile.totalScans)", color: .purple)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private func planDetail(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("includedFeatures", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(features, id: \.icon) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                            .frame(width: 30, height: 30)
                            .background(Color.orange.opacity(isDark ? 0.15 : 0.08))
                            .clipShape(.rect(cornerRadius: 8))
                        Text(feature.title)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private var manageSection: some View {
        VStack(spacing: 12) {
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                    Text(L.t("manageSubscription", lang))
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }
}
