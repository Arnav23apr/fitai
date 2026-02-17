import SwiftUI

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }
    @State private var appeared: Bool = false
    @State private var showSkip: Bool = false
    @State private var selectedPlan: Int = 1

    private let plans: [(title: String, price: String, period: String, badge: String?)] = [
        ("Monthly", "$9.99", "/month", nil),
        ("Annual", "$59.99", "/year", "BEST VALUE"),
        ("Lifetime", "$149.99", "one-time", nil)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                skipButton
                headerSection
                featuresSection
                plansSection
                ctaSection
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.spring(duration: 0.4)) {
                    showSkip = true
                }
            }
        }
    }

    private var skipButton: some View {
        HStack {
            Spacer()
            if showSkip {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
    }

    private var headerSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 8) {
                Text(L.t("unlockFitAIPro", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("premiumExperience", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(icon: "figure.run", title: "AI Workout Plans", subtitle: "Personalized to your goals")
            FeatureRow(icon: "camera.viewfinder", title: "Body Composition Scans", subtitle: "Unlimited AI-powered analysis")
            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", subtitle: "Detailed analytics & insights")
            FeatureRow(icon: "trophy.fill", title: "Compete & Earn", subtitle: "Leaderboards & challenges")
            FeatureRow(icon: "bolt.fill", title: "Priority AI Coach", subtitle: "Faster, smarter recommendations")
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(plans.enumerated()), id: \.offset) { index, plan in
                planRow(index: index, plan: plan)
            }
        }
        .padding(.top, 28)
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
    }

    private func planRow(index: Int, plan: (title: String, price: String, period: String, badge: String?)) -> some View {
        let isSelected = selectedPlan == index
        let bgColor = isSelected
            ? (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
            : (isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        let borderColor = isSelected
            ? (isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
            : Color.clear

        return Button(action: { selectedPlan = index }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                    }
                    Text(plan.price + " " + plan.period)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .primary : .tertiary)
            }
            .padding(16)
            .background(bgColor)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 8) {
            Button(action: onSubscribe) {
                Text(L.t("startFreeTrial", lang))
                    .font(.headline)
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Text(L.t("cancelAnytime", lang))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 32)
        }
        .opacity(appeared ? 1 : 0)
    }
}

struct FeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let subtitle: String

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
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
        .padding(.vertical, 8)
    }
}
