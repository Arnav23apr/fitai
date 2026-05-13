import SwiftUI

/// Privacy/trust beat. Hero is a chrome-haloed lock with three
/// outward pulse rings. The bullet titles arrive as scrambled glyphs
/// that "decrypt" into readable text — a literal visualization of
/// the "your data stays yours" promise.
///
/// Background is the shared `PremiumBackdrop` (breathing top
/// spotlight, FBM noise, vignette, film grain) so this screen sits
/// on the same canvas as WelcomeView and PlanPreview.
struct TrustUsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var headerAppeared: Bool = false
    @State private var lockClosed: Bool = false
    @State private var lockBounce: CGFloat = 1.0
    @State private var bulletsRevealed: Int = 0
    @State private var ctaTapCount: Int = 0
    /// Drives the breathing halation rim around the lock. Climbs to
    /// 1.0 on appear, then breathes 0.7 ↔ 1.0 forever.
    @State private var lockHalation: Double = 0
    /// Per-bullet decryption trigger. We flip each index on as its
    /// row reveals so `EncryptionShimmerText` can fire its scramble.
    @State private var decryptTriggers: [Bool] = [false, false, false]

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private struct Bullet {
        let icon: String
        let title: String
        let body: String
    }

    private var bullets: [Bullet] {
        [
            Bullet(
                icon: "lock.shield.fill",
                title: L.t("trustUsBullet1Title", lang),
                body:  L.t("trustUsBullet1Body",  lang)
            ),
            Bullet(
                icon: "trash.slash.fill",
                title: L.t("trustUsBullet2Title", lang),
                body:  L.t("trustUsBullet2Body",  lang)
            ),
            Bullet(
                icon: "dumbbell.fill",
                title: L.t("trustUsBullet3Title", lang),
                body:  L.t("trustUsBullet3Body",  lang)
            ),
        ]
    }

    var body: some View {
        ZStack {
            PremiumBackdrop()

            VStack(spacing: 0) {
                heroSection
                    .padding(.top, 56)

                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { idx, b in
                        bulletRow(b, index: idx, revealed: idx < bulletsRevealed)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
                Spacer(minLength: 0)

                ctaButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { runAppearChoreography() }
    }

    // MARK: - Hero (haloed lock + ambient pulse rings)

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                pulseRing(diameter: 140, delay: 0.0)
                pulseRing(diameter: 180, delay: 0.4)
                pulseRing(diameter: 220, delay: 0.8)

                // Frosted-glass lock chip with the lock symbol inside.
                // The chromatic-rim halation glow wraps the entire chip
                // and breathes on a 2s loop — the screen's "AI premium"
                // signature.
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 84, height: 84)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                        .frame(width: 84, height: 84)
                    Image(systemName: lockClosed ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
                .halationGlow(intensity: lockHalation)
                .scaleEffect(lockBounce)
            }
            .frame(height: 220)

            VStack(spacing: 6) {
                Text(L.t("trustUsTitle", lang))
                    .font(OnboardingTheme.headlineCompact())
                    .foregroundStyle(.white)
                Text(L.t("trustUsSubtitle", lang))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .opacity(headerAppeared ? 1 : 0)
            .blur(radius: headerAppeared ? 0 : 6)
            .offset(y: headerAppeared ? 0 : 12)
        }
    }

    /// Apple Privacy / FaceID-style outward pulse ring. Three of
    /// these stacked at staggered delays. Tinted white so they read
    /// as ambient light radiating from the lock against the dark
    /// `PremiumBackdrop`.
    private func pulseRing(diameter: CGFloat, delay: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate + delay
            let cycle = t.truncatingRemainder(dividingBy: 3.0) / 3.0
            let scale = 0.85 + cycle * 0.55
            let opacity = max(0, 0.32 * (1.0 - cycle))

            Circle()
                .strokeBorder(Color.white.opacity(opacity), lineWidth: 0.75)
                .frame(width: diameter, height: diameter)
                .scaleEffect(scale)
        }
    }

    // MARK: - Bullets

    private func bulletRow(_ b: Bullet, index: Int, revealed: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Monochrome icon chip — frosted glass surface with a
            // hairline stroke. The icon itself is the only signal
            // per bullet; no per-bullet color tints (which were the
            // designer's flag on the original).
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.75)
                    .frame(width: 40, height: 40)
                Image(systemName: b.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Title gets the encryption shimmer — the hero FX of
                // this screen. As each row reveals, its title briefly
                // renders as scrambled glyphs that decrypt into the
                // real text. Pairs with "your numbers stay yours".
                EncryptionShimmerText(
                    text: b.title,
                    duration: 0.7,
                    trigger: decryptTriggers[safe: index] ?? false
                )
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)

                Text(b.body)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .opacity(revealed ? 1 : 0)
        .blur(radius: revealed ? 0 : 4)
        .offset(x: revealed ? 0 : -12)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            ctaTapCount += 1
            onContinue()
        } label: {
            Text(L.t("trustUsCTA", lang))
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(.rect(cornerRadius: 28))
                .shadow(color: .white.opacity(0.08), radius: 36)
        }
        .opacity(headerAppeared ? 1 : 0)
        .scaleEffect(headerAppeared ? 1 : 0.94)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: headerAppeared)
        .sensoryFeedback(.selection, trigger: bulletsRevealed)
        .sensoryFeedback(.success, trigger: lockClosed)
        .sensoryFeedback(.impact(weight: .heavy), trigger: ctaTapCount)
    }

    // MARK: - Choreography

    private func runAppearChoreography() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            headerAppeared = true
        }

        // Lock "thunk": pops to 1.18, settles back to 1.0, then
        // closes with the symbol-replace transition.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                lockBounce = 1.18
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                lockBounce = 1.0
                lockClosed = true
            }
        }

        // Bring up the halation ring with the lock close, then loop
        // a 2s breathing modulation between 0.7 and 1.0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.6)) {
                lockHalation = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    lockHalation = 0.7
                }
            }
        }

        for i in 1...bullets.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65 + Double(i) * 0.18) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    bulletsRevealed = i
                }
                // Fire the decryption shimmer for this bullet's title
                // immediately after it slides in. Each row decrypts
                // independently for a staggered cascade.
                if decryptTriggers.indices.contains(i - 1) {
                    decryptTriggers[i - 1] = true
                }
            }
        }
    }
}

// Array.subscript(safe:) is defined module-wide in PlanView.swift.
