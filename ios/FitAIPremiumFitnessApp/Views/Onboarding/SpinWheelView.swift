import SwiftUI
import RevenueCat

struct SpinWheelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }
    @State private var appeared: Bool = false
    @State private var rotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var hasSpun: Bool = false
    @State private var resultDiscount: Int = 0
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showConfetti: Bool = false
    @State private var freeTrialEnabled: Bool = true
    @State private var isPurchasing: Bool = false
    @State private var landingGlow: Bool = false
    @State private var store = StoreViewModel.shared

    private let segments: [Int] = [10, 20, 85, 15, 50, 25, 40, 20]

    /// Computes the discounted annual price label based on the spin result.
    private var discountedPriceLabel: String {
        // Use the RevenueCat annual price if available
        if let pkg = store.annualPackage {
            let basePrice = pkg.storeProduct.price as Decimal
            let discountFraction = Decimal(resultDiscount) / 100
            let discounted = basePrice * (1 - discountFraction)
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = pkg.storeProduct.priceFormatter?.locale ?? .current
            return "\(formatter.string(from: discounted as NSDecimalNumber) ?? "$\(discounted)")/year"
        }
        // Fallback calculation from the default $119.99
        let base = 119.99
        let discounted = base * (1 - Double(resultDiscount) / 100)
        return String(format: "$%.2f/year", discounted)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    if hasSpun {
                        Text("Your offer is ready")
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                            .transition(.scale.combined(with: .opacity))
                        Text("\(resultDiscount)% off + 7-day free trial")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Your welcome offer")
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Spin once to reveal your launch pricing")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 48)
                .opacity(appeared ? 1 : 0)
                .animation(.snappy, value: hasSpun)

                Spacer()

                ZStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.primary)
                        .shadow(color: isDark ? .white.opacity(0.4) : .black.opacity(0.2), radius: 4)
                        .offset(y: -158)
                        .zIndex(1)

                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let radius = min(size.width, size.height) / 2
                        let segmentCount = segments.count
                        let segmentAngle = (2 * .pi) / Double(segmentCount)

                        for i in 0..<segmentCount {
                            let startAngle = Double(i) * segmentAngle - .pi / 2
                            let endAngle = startAngle + segmentAngle

                            var path = Path()
                            path.move(to: center)
                            path.addArc(center: center, radius: radius, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
                            path.closeSubpath()

                            let isEven = i % 2 == 0
                            let fillColor = isDark
                                ? (isEven ? Color.white.opacity(0.08) : Color.white.opacity(0.16))
                                : (isEven ? Color.black.opacity(0.04) : Color.black.opacity(0.1))
                            context.fill(path, with: .color(fillColor))

                            let midAngle = startAngle + segmentAngle / 2
                            let textRadius = radius * 0.68
                            let textPoint = CGPoint(
                                x: center.x + textRadius * cos(midAngle),
                                y: center.y + textRadius * sin(midAngle)
                            )

                            context.drawLayer { ctx in
                                ctx.translateBy(x: textPoint.x, y: textPoint.y)
                                ctx.rotate(by: .radians(midAngle + .pi / 2))
                                let text = Text("\(segments[i])%")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                ctx.draw(text, at: .zero)
                            }
                        }
                    }
                    .frame(width: 290, height: 290)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: isDark
                                        ? [.white.opacity(0.3), .white.opacity(0.08)]
                                        : [.black.opacity(0.2), .black.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 3
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isDark ? .white.opacity(0.05) : .black.opacity(0.03), lineWidth: 8)
                            .padding(-4)
                    )
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: isDark ? .white.opacity(0.05) : .black.opacity(0.08), radius: 20)
                    .overlay(
                        // Landing glow — pulses out from the wheel when the
                        // result lands. Subtle but rewarding without confetti
                        // overload.
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.7), .orange.opacity(0.5), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: landingGlow ? 18 : 0
                            )
                            .blur(radius: landingGlow ? 12 : 0)
                            .opacity(landingGlow ? 1 : 0)
                            .scaleEffect(landingGlow ? 1.18 : 1.0)
                            .animation(.easeOut(duration: 1.4), value: landingGlow)
                    )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isDark ? [Color(white: 0.15), Color.black] : [Color(white: 0.95), Color.white],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .strokeBorder(isDark ? Color.white.opacity(0.25) : Color.black.opacity(0.15), lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "star.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.primary)
                        )
                        .shadow(color: isDark ? .black.opacity(0.5) : .black.opacity(0.15), radius: 8)
                }
                .opacity(appeared ? 1 : 0)

                Spacer()

                if hasSpun {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("7-day free trial")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Toggle("", isOn: $freeTrialEnabled)
                                .tint(.green)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 6) {
                            Button(action: claimDiscount) {
                                HStack(spacing: 8) {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(Color(.systemBackground))
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14))
                                        Text("Claim my offer — \(discountedPriceLabel)")
                                            .font(.headline)
                                    }
                                }
                                .foregroundStyle(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.primary)
                                .clipShape(.rect(cornerRadius: 16))
                            }
                            .disabled(isPurchasing)

                            Text(freeTrialEnabled
                                 ? "Cancel anytime in Settings. \(discountedPriceLabel) after the 7-day trial."
                                 : "Cancel anytime in Settings. \(discountedPriceLabel) billed today.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button(action: spinWheel) {
                        Text(L.t("spinTheWheel", lang))
                            .font(.headline)
                            .foregroundStyle(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isSpinning ? Color.primary.opacity(0.3) : Color.primary)
                            .clipShape(.rect(cornerRadius: 16))
                    }
                    .disabled(isSpinning)
                    .padding(.horizontal, 24)
                }

                Button(action: onContinue) {
                    Text(L.t("noThanks", lang))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
            }

            if showConfetti {
                ConfettiView(particles: confettiParticles)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium {
                appState.profile.isPremium = true
                appState.saveProfile()
                onContinue()
            }
        }
    }

    private func spinWheel() {
        guard !isSpinning else { return }
        isSpinning = true

        let selectedIndex = 2
        resultDiscount = segments[selectedIndex]

        let segmentAngle = 360.0 / Double(segments.count)
        let targetAngle = 360.0 - (Double(selectedIndex) * segmentAngle + segmentAngle / 2.0)
        let totalRotation = 360.0 * 5 + targetAngle

        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 4.5)) {
            rotation += totalRotation
        }

        // Detent haptics — fire one tick per wheel segment as the rotation
        // slows. Spaced exponentially so they thin out near the end, mimicking
        // a real ratchet wheel decelerating under friction.
        Task {
            let detents = 24
            let totalDuration: Double = 4.5
            for i in 0..<detents {
                let t = Double(i) / Double(detents)
                // Ease-out spacing: gaps grow as i increases.
                let progress = 1 - pow(1 - t, 2.4)
                let delay = totalDuration * progress
                try? await Task.sleep(for: .seconds(delay - (i == 0 ? 0 : (totalDuration * (1 - pow(1 - Double(i - 1) / Double(detents), 2.4))))))
                let style: UIImpactFeedbackGenerator.FeedbackStyle = i > detents - 4 ? .heavy : (i > detents / 2 ? .medium : .light)
                await MainActor.run {
                    UIImpactFeedbackGenerator(style: style).impactOccurred()
                }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(4.7))
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                landingGlow = true
            }
            triggerConfetti()
            withAnimation(.snappy) {
                hasSpun = true
                isSpinning = false
            }
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run { landingGlow = false }
        }
    }

    private func claimDiscount() {
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            guard let pkg = store.annualPackage else {
                appState.profile.isPremium = true
                appState.profile.spinDiscount = resultDiscount
                appState.saveProfile()
                onContinue()
                return
            }
            let success = await store.purchase(package: pkg)
            if success {
                appState.profile.isPremium = true
                appState.profile.spinDiscount = resultDiscount
                appState.saveProfile()
                onContinue()
            }
        }
    }

    private func triggerConfetti() {
        let emojis = ["🎉", "🥳", "🎊", "🎈", "✨", "💪", "🏆", "⭐️"]
        var particles: [ConfettiParticle] = []
        for i in 0..<40 {
            particles.append(ConfettiParticle(
                id: i,
                emoji: emojis[i % emojis.count],
                startX: CGFloat.random(in: 0.1...0.9),
                startDelay: Double.random(in: 0...0.4),
                horizontalDrift: CGFloat.random(in: -60...60),
                duration: Double.random(in: 2.0...3.5)
            ))
        }
        confettiParticles = particles
        withAnimation { showConfetti = true }
        Task {
            try? await Task.sleep(for: .seconds(4.0))
            withAnimation { showConfetti = false }
        }
    }
}

nonisolated struct ConfettiParticle: Identifiable, Sendable {
    let id: Int
    let emoji: String
    let startX: CGFloat
    let startDelay: Double
    let horizontalDrift: CGFloat
    let duration: Double
}

struct ConfettiView: View {
    let particles: [ConfettiParticle]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(particle: particle, screenHeight: geo.size.height, screenWidth: geo.size.width)
                }
            }
        }
    }
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat
    let screenWidth: CGFloat
    @State private var animate: Bool = false

    var body: some View {
        Text(particle.emoji)
            .font(.system(size: CGFloat.random(in: 22...36)))
            .position(
                x: particle.startX * screenWidth + (animate ? particle.horizontalDrift : 0),
                y: animate ? -60 : screenHeight + 40
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(
                    .easeOut(duration: particle.duration)
                    .delay(particle.startDelay)
                ) {
                    animate = true
                }
            }
    }
}
