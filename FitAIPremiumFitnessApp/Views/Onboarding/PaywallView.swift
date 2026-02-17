import SwiftUI

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    private var lang: String { appState.profile.selectedLanguage }
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
                HStack {
                    Spacer()
                    if showSkip {
                        Button(action: onSkip) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)

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
                            .foregroundStyle(.white)
                        Text(L.t("premiumExperience", lang))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .opacity(appeared ? 1 : 0)

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

                VStack(spacing: 12) {
                    ForEach(Array(plans.enumerated()), id: \.offset) { index, plan in
                        Button(action: { selectedPlan = index }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(plan.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
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
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: selectedPlan == index ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedPlan == index ? .white : .white.opacity(0.3))
                            }
                            .padding(16)
                            .background(selectedPlan == index ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                            .clipShape(.rect(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(selectedPlan == index ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.top, 28)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)

                Button(action: onSubscribe) {
                    Text(L.t("startFreeTrial", lang))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)

                Text(L.t("cancelAnytime", lang))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 8)
                    .padding(.bottom, 32)
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
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
