import SwiftUI

struct PhysiqueRewardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var headerAppeared: Bool = false
    @State private var cardsRevealed: Int = 0
    @State private var statPunch: [Bool] = [false, false, false]
    @State private var ctaAppeared: Bool = false
    /// Bumped on tap so the heavy CTA haptic fires on press, not appear.
    @State private var ctaTapCount: Int = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private struct RewardCard {
        let stat: String
        let body: String
        let source: String
        let icon: String
        let tint: Color
    }

    private var cards: [RewardCard] {
        [
            RewardCard(
                stat:   L.t("rewardCard1Stat", lang),
                body:   L.t("rewardCard1Body", lang),
                source: L.t("rewardCard1Source", lang),
                icon:   "heart.fill",
                tint:   Color(red: 1.00, green: 0.30, blue: 0.45)
            ),
            RewardCard(
                stat:   L.t("rewardCard2Stat", lang),
                body:   L.t("rewardCard2Body", lang),
                source: L.t("rewardCard2Source", lang),
                icon:   "person.fill.checkmark",
                tint:   Color(red: 0.20, green: 0.55, blue: 1.00)
            ),
            RewardCard(
                stat:   L.t("rewardCard3Stat", lang),
                body:   L.t("rewardCard3Body", lang),
                source: L.t("rewardCard3Source", lang),
                icon:   "bolt.fill",
                tint:   Color(red: 1.00, green: 0.62, blue: 0.10)
            ),
        ]
    }

    var body: some View {
        ZStack {
            // Stronger aurora + parallax. Higher alpha lets the colors come
            // through the glass cards. Without parallax the screen reads as
            // static — Apple's onboarding pages all do gravity-driven drift.
            ParallaxBackground(amount: 10) {
                AuroraBackground(
                    colors: [
                        Color(red: 1.00, green: 0.30, blue: 0.45).opacity(isDark ? 0.18 : 0.12),
                        Color(red: 0.20, green: 0.55, blue: 1.00).opacity(isDark ? 0.16 : 0.10),
                        Color(red: 1.00, green: 0.62, blue: 0.10).opacity(isDark ? 0.14 : 0.09),
                        Color(red: 0.85, green: 0.40, blue: 1.00).opacity(isDark ? 0.10 : 0.06),
                        Color.clear,
                    ],
                    speed: 0.10
                )
            }
            .ignoresSafeArea()

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
            Text("RESEARCH BACKED")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(.secondary)
                .opacity(headerAppeared ? 1 : 0)

            VStack(spacing: 2) {
                Text(L.t("rewardTitle", lang))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("rewardTitle2", lang))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : 12)

            Text(L.t("rewardSubtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .opacity(headerAppeared ? 1 : 0)
        }
    }

    // MARK: - Card

    private func cardView(_ c: RewardCard, index: Int, revealed: Bool) -> some View {
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
                    .modifier(SpecularSweep(active: statPunch[safeIdx: index] ?? false, tint: c.tint))
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
                Image(systemName: "checkmark.seal.fill")
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
            // Liquid-glass card — material backdrop + soft tint wash so the
            // aurora behind colors through the glass like the iOS 26 system
            // look. Without the wash the cards read as flat white.
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(c.tint.opacity(isDark ? 0.06 : 0.035))
            }
        )
        .overlay(
            // Top-edge highlight: thin gradient stroke that fakes a light
            // source from above. Apple's signature for premium cards.
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.18 : 0.55),
                            c.tint.opacity(revealed ? 0.18 : 0),
                            Color.white.opacity(isDark ? 0.04 : 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
        )
        .shadow(color: c.tint.opacity(isDark ? 0.18 : 0.10), radius: 18, y: 8)
        .shadow(color: Color.black.opacity(isDark ? 0 : 0.04), radius: 2, y: 1)
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
        // Layered haptics: header lands → light, each card reveal →
        // selection tick, stat punch → success-style notification, CTA
        // press → heavy thump. Each `.sensoryFeedback` is independent.
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: headerAppeared)
        .sensoryFeedback(.selection, trigger: cardsRevealed)
        .sensoryFeedback(.success, trigger: statPunch[2])
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

// MARK: - Specular sweep

/// Single pass of a glossy highlight wiping diagonally across the text once
/// `active` flips true. Implemented as a TimelineView-driven mask so it runs
/// on the SwiftUI renderer (which targets Metal) without a custom .metal file.
private struct SpecularSweep: ViewModifier {
    let active: Bool
    let tint: Color
    @State private var t: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: .clear,               location: 0.0),
                                Gradient.Stop(color: .white.opacity(0.85), location: 0.5),
                                Gradient.Stop(color: .clear,               location: 1.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: w * 0.45)
                        .offset(x: t * w * 1.6 - w * 0.2)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }
                    .mask(content)
                }
            }
            .onChange(of: active) { _, newValue in
                guard newValue else { return }
                t = -1.0
                withAnimation(.easeOut(duration: 0.85)) { t = 1.2 }
            }
    }
}

// MARK: - Parallax background wrapper

/// Wraps any background view and applies a subtle device-tilt parallax —
/// content drifts ±6pt with gravity. Apple's signature for premium
/// onboarding screens. CMMotionManager updates at 30Hz.
struct ParallaxBackground<Content: View>: View {
    let content: Content
    var amount: CGFloat = 8

    init(amount: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.amount = amount
        self.content = content()
    }

    @State private var offset: CGSize = .zero
    @State private var motion = MotionPublisher()

    var body: some View {
        content
            .scaleEffect(1.06) // overscan so the parallax never reveals the screen edge
            .offset(offset)
            .onReceive(motion.gravityPublisher) { g in
                withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                    offset = CGSize(width: CGFloat(g.x) * amount, height: CGFloat(-g.y) * amount * 0.6)
                }
            }
    }
}

import CoreMotion
import Combine

@MainActor
final class MotionPublisher: ObservableObject {
    private let manager = CMMotionManager()
    let gravityPublisher = PassthroughSubject<CMAcceleration, Never>()

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            self?.gravityPublisher.send(g)
        }
    }

    deinit { manager.stopDeviceMotionUpdates() }
}
