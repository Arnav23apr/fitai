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
    @State private var freeTrialEnabled: Bool = false
    @State private var isPurchasing: Bool = false
    @State private var store = StoreViewModel.shared

    private let segments: [Int] = [10, 20, 85, 15, 50, 25, 40, 20]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    if hasSpun {
                        Text("🥳 You won \(resultDiscount)%! 🥳")
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(L.t("spinToWin", lang))
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(L.t("getExclusiveDiscount", lang))
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
                            Text("3-day free trial")
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
                                            .tint(isDark ? .black : .white)
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 14))
                                        Text("Claim 85% Off — $69.99/year")
                                            .font(.headline)
                                    }
                                }
                                .foregroundStyle(isDark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isDark ? Color.white : Color.black)
                                .clipShape(.rect(cornerRadius: 16))
                            }
                            .disabled(isPurchasing)

                            if freeTrialEnabled {
                                Text("Start your 3-day free trial, then $69.99/year")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button(action: spinWheel) {
                        Text(L.t("spinTheWheel", lang))
                            .font(.headline)
                            .foregroundStyle(isDark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isSpinning ? (isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)) : (isDark ? Color.white : Color.black))
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

        Task {
            try? await Task.sleep(for: .seconds(4.7))
            triggerConfetti()
            withAnimation(.snappy) {
                hasSpun = true
                isSpinning = false
            }
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
