import SwiftUI

struct TrustUsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var headerAppeared: Bool = false
    @State private var lockClosed: Bool = false
    @State private var lockBounce: CGFloat = 1.0
    @State private var bulletsRevealed: Int = 0
    @State private var ctaTapCount: Int = 0
    @State private var ringPulse: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private struct Bullet {
        let icon: String
        let title: String
        let body: String
        let tint: Color
    }

    private var bullets: [Bullet] {
        [
            Bullet(
                icon: "lock.shield.fill",
                title: L.t("trustUsBullet1Title", lang),
                body:  L.t("trustUsBullet1Body",  lang),
                tint:  Color(red: 0.20, green: 0.55, blue: 1.00)
            ),
            Bullet(
                icon: "trash.slash.fill",
                title: L.t("trustUsBullet2Title", lang),
                body:  L.t("trustUsBullet2Body",  lang),
                tint:  Color(red: 1.00, green: 0.32, blue: 0.40)
            ),
            Bullet(
                icon: "dumbbell.fill",
                title: L.t("trustUsBullet3Title", lang),
                body:  L.t("trustUsBullet3Body",  lang),
                tint:  Color(red: 1.00, green: 0.62, blue: 0.10)
            ),
        ]
    }

    var body: some View {
        ZStack {
            AuroraBackground(
                colors: [
                    Color.blue.opacity(isDark ? 0.10 : 0.06),
                    Color.indigo.opacity(isDark ? 0.08 : 0.04),
                    Color.cyan.opacity(isDark ? 0.06 : 0.03),
                    Color.clear,
                    Color.clear,
                ],
                speed: 0.10
            )

            VStack(spacing: 0) {
                heroSection
                    .padding(.top, 56)

                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { idx, b in
                        bulletRow(b, revealed: idx < bulletsRevealed)
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
        .onAppear { runAppearChoreography() }
    }

    // MARK: - Hero (lock + concentric rings)

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                pulseRing(diameter: 140, delay: 0.0)
                pulseRing(diameter: 180, delay: 0.4)
                pulseRing(diameter: 220, delay: 0.8)

                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(isDark ? 0.30 : 0.08), radius: 14, y: 6)

                Image(systemName: lockClosed ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .scaleEffect(lockBounce)
            }
            .frame(height: 220)

            VStack(spacing: 6) {
                Text(L.t("trustUsTitle", lang))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("trustUsSubtitle", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(headerAppeared ? 1 : 0)
            .blur(radius: headerAppeared ? 0 : 6)
            .offset(y: headerAppeared ? 0 : 12)
        }
    }

    /// Apple Privacy / FaceID-style outward pulse ring. Three of these
    /// stacked on different delays gives the "trust circle" radiate effect.
    private func pulseRing(diameter: CGFloat, delay: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate + delay
            let cycle = t.truncatingRemainder(dividingBy: 3.0) / 3.0
            let scale = 0.85 + cycle * 0.55
            let opacity = max(0, 0.22 * (1.0 - cycle))

            Circle()
                .strokeBorder(Color.primary.opacity(opacity), lineWidth: 0.75)
                .frame(width: diameter, height: diameter)
                .scaleEffect(scale)
        }
    }

    // MARK: - Bullets

    private func bulletRow(_ b: Bullet, revealed: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(b.tint.opacity(0.12))
                    .frame(width: 40, height: 40)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(b.tint.opacity(0.18), lineWidth: 0.5)
                    .frame(width: 40, height: 40)
                Image(systemName: b.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(b.tint)
            }
            .shadow(color: b.tint.opacity(isDark ? 0.20 : 0.12), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(b.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(b.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.primary)
                .clipShape(.rect(cornerRadius: 28))
                .shadow(color: .black.opacity(isDark ? 0 : 0.18), radius: 14, y: 6)
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

        // Lock "thunk": pops to 1.18, settles back to 1.0, then closes
        // with the symbol-replace transition while a success haptic fires.
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

        for i in 1...bullets.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65 + Double(i) * 0.18) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    bulletsRevealed = i
                }
            }
        }
    }
}
