import SwiftUI

struct CurrentPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    @State private var appeared: Bool = false
    @State private var crownScale: CGFloat = 0.6

    private let features: [(icon: String, title: String)] = [
        ("figure.run", "AI Workouts"),
        ("camera.viewfinder", "Unlimited Scans"),
        ("chart.line.uptrend.xyaxis", "Analytics"),
        ("trophy.fill", "Compete"),
        ("bolt.fill", "AI Coach"),
        ("sparkles", "All Features")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.25), .orange.opacity(0.1), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(crownScale)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(appeared ? 1 : 0.6)
                }

                Text("FitAI Pro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(L.t("activePlan", lang))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            featuresCard
                .opacity(appeared ? 1 : 0)

            HStack(spacing: 0) {
                statItem(value: L.t("active", lang), label: L.t("status", lang), color: .green)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 32)
                statItem(value: "\(appState.profile.totalWorkouts)", label: L.t("workouts", lang), color: .blue)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 32)
                statItem(value: "\(appState.profile.totalScans)", label: L.t("scans", lang), color: .purple)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)

            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 13, weight: .medium))
                    Text(L.t("manageSubscription", lang))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                crownScale = 1.0
            }
        }
    }

    private var featuresCard: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(features, id: \.icon) { feature in
                VStack(spacing: 8) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 36, height: 36)
                        .background(Color.orange.opacity(isDark ? 0.12 : 0.08))
                        .clipShape(.rect(cornerRadius: 10))

                    Text(feature.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
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
}
