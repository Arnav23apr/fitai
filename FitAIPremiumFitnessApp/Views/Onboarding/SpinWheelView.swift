import SwiftUI

struct SpinWheelView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void

    private var lang: String { appState.profile.selectedLanguage }
    @State private var appeared: Bool = false
    @State private var rotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var hasSpun: Bool = false
    @State private var resultDiscount: Int = 0
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showConfetti: Bool = false

    private let segments: [Int] = [10, 20, 85, 15, 50, 25, 40, 20]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    if hasSpun {
                        Text("🥳 You won \(resultDiscount)%! 🥳")
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(L.t("spinToWin", lang))
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.white)
                        Text(L.t("getExclusiveDiscount", lang))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.top, 48)
                .opacity(appeared ? 1 : 0)
                .animation(.snappy, value: hasSpun)

                Spacer()

                ZStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 4)
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
                            context.fill(path, with: .color(isEven ? Color.white.opacity(0.08) : Color.white.opacity(0.16)))

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
                                    .foregroundStyle(.white)
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
                                    colors: [.white.opacity(0.3), .white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 3
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.05), lineWidth: 8)
                            .padding(-4)
                    )
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .white.opacity(0.05), radius: 20)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.15), Color.black],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "star.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 8)
                }
                .opacity(appeared ? 1 : 0)

                Spacer()

                if hasSpun {
                    Button(action: {
                        appState.profile.spinDiscount = resultDiscount
                        appState.profile.isPremium = true
                        onContinue()
                    }) {
                        Text("Claim \(resultDiscount)% Off")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white)
                            .clipShape(.rect(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button(action: spinWheel) {
                        Text(L.t("spinTheWheel", lang))
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isSpinning ? Color.white.opacity(0.3) : Color.white)
                            .clipShape(.rect(cornerRadius: 16))
                    }
                    .disabled(isSpinning)
                    .padding(.horizontal, 24)
                }

                Button(action: onContinue) {
                    Text(L.t("noThanks", lang))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
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
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
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
        withAnimation {
            showConfetti = true
        }
        Task {
            try? await Task.sleep(for: .seconds(4.0))
            withAnimation {
                showConfetti = false
            }
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
