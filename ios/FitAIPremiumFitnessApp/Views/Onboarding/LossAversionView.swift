import SwiftUI

/// Loss-aversion / cost-of-inaction screen. Pairs with PhysiqueRewardView
/// (gain framing) so the user feels both sides of the contrast.
/// Kahneman/Tversky: loss-framing converts ~2× better than gain-framing
/// in the same audience. Three research-stat cards with downward
/// indicators — the visual mirror image of the reward screen.
struct LossAversionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var headerAppeared: Bool = false
    @State private var cardsRevealed: Int = 0
    @State private var statPunch: [Bool] = [false, false, false]
    @State private var ctaAppeared: Bool = false
    @State private var ctaTapCount: Int = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private struct LossCard {
        let stat: String
        let body: String
        let source: String
        let icon: String
        let tint: Color
    }

    private var cards: [LossCard] {
        [
            LossCard(
                stat:   L.t("lossCard1Stat", lang),
                body:   L.t("lossCard1Body", lang),
                source: L.t("lossCard1Source", lang),
                icon:   "arrow.down.right",
                tint:   Color(red: 0.95, green: 0.30, blue: 0.30)
            ),
            LossCard(
                stat:   L.t("lossCard2Stat", lang),
                body:   L.t("lossCard2Body", lang),
                source: L.t("lossCard2Source", lang),
                icon:   "figure.fall",
                tint:   Color(red: 0.85, green: 0.40, blue: 0.30)
            ),
            LossCard(
                stat:   L.t("lossCard3Stat", lang),
                body:   L.t("lossCard3Body", lang),
                source: L.t("lossCard3Source", lang),
                icon:   "exclamationmark.triangle.fill",
                tint:   Color(red: 0.95, green: 0.55, blue: 0.20)
            ),
        ]
    }

    var body: some View {
        ZStack {
            AuroraBackground(
                colors: [
                    Color.red.opacity(isDark ? 0.10 : 0.05),
                    Color.orange.opacity(isDark ? 0.08 : 0.04),
                    Color.clear,
                    Color.clear,
                ],
                speed: 0.10
            )

            // Metal-rendered drifting embers — reinforces the
            // "time is running out" theme. GPU-cheap (14 particles @ 30fps).
            MetalEmbersOverlay()

            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 48)
                    .padding(.bottom, 28)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { idx, c in
                        cardView(c, index: idx, revealed: idx < cardsRevealed)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

                ctaButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .onAppear { runAppearChoreography() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("THE COST OF WAITING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(.red.opacity(0.75))
                .opacity(headerAppeared ? 1 : 0)

            VStack(spacing: 2) {
                Text(L.t("lossTitle", lang))
                    .font(OnboardingTheme.headlineCompact())
                    .foregroundStyle(.primary)
                Text(L.t("lossTitle2", lang))
                    .font(OnboardingTheme.headlineCompact())
                    .foregroundStyle(.primary)
            }
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : 12)

            Text(L.t("lossSubtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .opacity(headerAppeared ? 1 : 0)
        }
    }

    // MARK: - Card

    private func cardView(_ c: LossCard, index: Int, revealed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(c.tint.opacity(0.14))
                    Circle()
                        .strokeBorder(c.tint.opacity(0.18), lineWidth: 0.5)
                    Image(systemName: c.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(c.tint)
                }
                .frame(width: 32, height: 32)

                Text(c.stat)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(c.tint)
                    .scaleEffect(statPunch[safeIdx: index] ?? false ? 1.0 : 0.85)
                    .opacity(statPunch[safeIdx: index] ?? false ? 1 : 0)

                Spacer(minLength: 0)
            }

            Text(c.body)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 9))
                    .foregroundStyle(c.tint.opacity(0.7))
                Text(c.source)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isDark ? Color.white.opacity(0.04) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(c.tint.opacity(revealed ? 0.10 : 0), lineWidth: 0.5)
        )
        .shadow(color: c.tint.opacity(isDark ? 0.10 : 0.06), radius: 12, y: 4)
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 26)
        .scaleEffect(revealed ? 1 : 0.96)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            ctaTapCount += 1
            onContinue()
        } label: {
            HStack(spacing: 8) {
                Text(L.t("continue", lang))
                    .font(.system(.headline, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primary)
            .clipShape(.rect(cornerRadius: 28))
            .shadow(color: .black.opacity(isDark ? 0 : 0.18), radius: 14, y: 6)
        }
        .opacity(ctaAppeared ? 1 : 0)
        .scaleEffect(ctaAppeared ? 1 : 0.94)
        .offset(y: ctaAppeared ? 0 : 12)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: headerAppeared)
        .sensoryFeedback(.selection, trigger: cardsRevealed)
        .sensoryFeedback(.warning, trigger: statPunch[2])
        .sensoryFeedback(.impact(weight: .heavy), trigger: ctaTapCount)
    }

    // MARK: - Choreography

    private func runAppearChoreography() {
        withAnimation(.spring(duration: 0.7, bounce: 0.18)) {
            headerAppeared = true
        }

        for i in 1...cards.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40 + Double(i) * 0.16) {
                withAnimation(.spring(duration: 0.55, bounce: 0.28)) {
                    cardsRevealed = i
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(duration: 0.45, bounce: 0.45)) {
                        if statPunch.indices.contains(i - 1) {
                            statPunch[i - 1] = true
                        }
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40 + Double(cards.count) * 0.16 + 0.25) {
            withAnimation(.spring(duration: 0.55, bounce: 0.20)) {
                ctaAppeared = true
            }
        }
    }
}

private extension Array {
    subscript(safeIdx index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
