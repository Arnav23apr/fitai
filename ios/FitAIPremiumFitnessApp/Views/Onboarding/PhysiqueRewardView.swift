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
    }

    private var cards: [RewardCard] {
        [
            RewardCard(
                stat:   L.t("rewardCard1Stat", lang),
                body:   L.t("rewardCard1Body", lang),
                source: L.t("rewardCard1Source", lang),
                icon:   "heart.fill"
            ),
            RewardCard(
                stat:   L.t("rewardCard2Stat", lang),
                body:   L.t("rewardCard2Body", lang),
                source: L.t("rewardCard2Source", lang),
                icon:   "person.fill.checkmark"
            ),
            RewardCard(
                stat:   L.t("rewardCard3Stat", lang),
                body:   L.t("rewardCard3Body", lang),
                source: L.t("rewardCard3Source", lang),
                icon:   "bolt.fill"
            ),
        ]
    }

    var body: some View {
        ZStack {
            // Shared PremiumBackdrop puts this screen on the same
            // canvas as WelcomeView and PlanPreview — breathing top
            // spotlight, FBM noise, vignette, film grain. That's all
            // the ambient color this screen needs; the previous
            // caustic underlay overpowered the cards and was removed.
            PremiumBackdrop()

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
        .preferredColorScheme(.dark)
        .onAppear { runAppearChoreography() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("RESEARCH BACKED")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.65))
                .opacity(headerAppeared ? 1 : 0)

            VStack(spacing: 2) {
                Text(L.t("rewardTitle", lang))
                    .font(OnboardingTheme.headlineCompact())
                    .foregroundStyle(.white)
                Text(L.t("rewardTitle2", lang))
                    .font(OnboardingTheme.headlineCompact())
                    .foregroundStyle(.white)
            }
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : 12)

            Text(L.t("rewardSubtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 4)
                .opacity(headerAppeared ? 1 : 0)
        }
    }

    // MARK: - Card

    private func cardView(_ c: RewardCard, index: Int, revealed: Bool) -> some View {
        let statActive = statPunch[safeIdx: index] ?? false
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                // Monochrome icon chip — frosted glass surface with
                // hairline stroke. One material everywhere, no per-card
                // tint.
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.75)
                    Image(systemName: c.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                CountUpStat(stat: c.stat, trigger: statActive)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(statActive ? 1.0 : 0.85)
                    .opacity(statActive ? 1 : 0)

                Spacer(minLength: 0)
            }

            Text(c.body)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
                Text(c.source)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
        )
        // God-ray sweep — fires once when this card's stat lands.
        // Emanates from the stat number's position (leading edge of
        // the card, just inside the icon chip) outward across the card.
        .godRaySweep(
            active: statActive,
            duration: 0.55,
            origin: UnitPoint(x: 0.15, y: 0.30)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.20), radius: 12, y: 6)
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

// MARK: - Count-up stat

/// Stat headline that parses a string like "+20%", "2×", or "Free"
/// and rolls the numeric portion from 0 to target with an ease-out
/// curve when `trigger` flips true. Non-numeric strings fall back to
/// a static Text so "Free" still works inside the same call site.
///
/// Foreground style is left to the caller — this is just the
/// animating glyph, not the styling.
private struct CountUpStat: View {
    let stat: String
    var duration: Double = 0.85
    let trigger: Bool

    @State private var value: Int = 0

    var body: some View {
        Group {
            if let parts = Self.parse(stat) {
                Text("\(parts.prefix)\(value)\(parts.suffix)")
                    .contentTransition(.numericText())
            } else {
                Text(stat)
            }
        }
        .onChange(of: trigger) { _, newValue in
            guard newValue, let parts = Self.parse(stat) else { return }
            runCountUp(target: parts.value)
        }
    }

    private func runCountUp(target: Int) {
        // Two frames per integer unit gives a smooth roll; floor at
        // 8 frames so small numbers ("2×") still feel rolled, not
        // snapped.
        let frames = max(target * 2, 8)
        let step = duration / Double(frames)
        for i in 0...frames {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * step) {
                let progress = Double(i) / Double(frames)
                let eased = 1 - pow(1 - progress, 3)
                withAnimation(.linear(duration: step * 0.9)) {
                    value = Int(Double(target) * eased)
                }
            }
        }
    }

    private static func parse(_ s: String) -> (prefix: String, value: Int, suffix: String)? {
        // Leading sign, digits, then anything as a suffix. Integer
        // only — onboarding stats are always whole numbers.
        let pattern = #"^([+\-]?)(\d+)(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let match = regex.firstMatch(in: s, range: range), match.numberOfRanges >= 4 else { return nil }
        let extract: (Int) -> String = { idx in
            if let r = Range(match.range(at: idx), in: s) { return String(s[r]) }
            return ""
        }
        guard let value = Int(extract(2)) else { return nil }
        return (extract(1), value, extract(3))
    }
}

// MARK: - Specular sweep

/// Single pass of a glossy highlight wiping diagonally across the text once
/// `active` flips true. Implemented as a TimelineView-driven mask so it runs
/// on the SwiftUI renderer (which targets Metal) without a custom .metal file.
/// Single pass of a glossy highlight wiping diagonally across the
/// content once `active` flips true — then re-fires every `loopPeriod`
/// seconds so the metal surface continuously catches light. Each
/// SpecularSweep runs on its own offset, so three stacked cards never
/// flash in lockstep.
private struct SpecularSweep: ViewModifier {
    let active: Bool
    var sweepDuration: Double = 0.85
    var loopPeriod: Double = 6.0
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
                                Gradient.Stop(color: .white.opacity(0.65), location: 0.5),
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
                runSweepLoop()
            }
    }

    private func runSweepLoop() {
        // Reset offscreen, then wipe across.
        t = -1.0
        withAnimation(.easeOut(duration: sweepDuration)) { t = 1.2 }
        // Schedule the next pass. We only re-arm while still active —
        // when the parent view disappears, `active` won't flip back to
        // true, so this chain quietly stops.
        DispatchQueue.main.asyncAfter(deadline: .now() + loopPeriod) {
            if active { runSweepLoop() }
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
