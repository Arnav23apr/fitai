import SwiftUI

struct WelcomeProView: View {
    var onStartJourney: () -> Void

    @State private var phase: Int = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var glowScale: CGFloat = 0.8
    @State private var particleOpacity: Double = 0

    var body: some View {
        ZStack {
            backgroundLayer

            particleField

            VStack(spacing: 0) {
                Spacer()

                glassCard
                    .opacity(phase >= 1 ? 1 : 0)
                    .offset(y: phase >= 1 ? 0 : 40)
                    .scaleEffect(phase >= 1 ? 1 : 0.92)

                Spacer()

                ctaButton
                    .opacity(phase >= 2 ? 1 : 0)
                    .offset(y: phase >= 2 ? 0 : 20)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { runEntrance() }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.green.opacity(0.15),
                    Color.purple.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 400
            )
            .scaleEffect(glowScale)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.green.opacity(0.06),
                    Color.clear
                ],
                center: .top,
                startRadius: 50,
                endRadius: 350
            )
            .ignoresSafeArea()
        }
    }

    private var particleField: some View {
        Canvas { context, size in
            let positions: [(CGFloat, CGFloat, CGFloat)] = [
                (0.15, 0.2, 2.0), (0.8, 0.15, 1.5), (0.3, 0.75, 1.8),
                (0.7, 0.6, 1.2), (0.5, 0.4, 2.5), (0.9, 0.8, 1.0),
                (0.1, 0.55, 1.6), (0.6, 0.25, 1.3), (0.4, 0.85, 2.2),
                (0.85, 0.45, 1.7), (0.25, 0.35, 1.1), (0.55, 0.7, 1.9)
            ]
            for (x, y, r) in positions {
                let rect = CGRect(
                    x: x * size.width - r,
                    y: y * size.height - r,
                    width: r * 2,
                    height: r * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.3))
                )
            }
        }
        .opacity(particleOpacity)
        .allowsHitTesting(false)
    }

    private var glassCard: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4), radius: 20, y: 4)
            }

            proBadge

            VStack(spacing: 10) {
                Text("Welcome to Fit AI Pro")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("You've unlocked advanced physique analysis, elite tracking, and AI-powered coaching.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 28)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .clear, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerOffset)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .allowsHitTesting(false)
        }
    }

    private var proBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("PRO ACTIVATED")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
        }
        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.12))
                .overlay {
                    Capsule()
                        .strokeBorder(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3), lineWidth: 1)
                }
        }
    }

    private var ctaButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onStartJourney()
        } label: {
            Text("Start My Journey")
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .white.opacity(0.15), radius: 20, y: 8)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(PremiumButtonStyle())
    }

    private func runEntrance() {
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            phase = 1
            glowScale = 1.1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
            phase = 2
        }
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            particleOpacity = 1
        }
        withAnimation(.easeInOut(duration: 2.0).delay(1.0)) {
            shimmerOffset = 400
        }
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(0.5)) {
            glowScale = 1.2
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
