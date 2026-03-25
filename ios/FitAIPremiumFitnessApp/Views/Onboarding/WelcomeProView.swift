import SwiftUI

struct WelcomeProView: View {
    var onContinue: () -> Void

    @State private var appeared: Bool = false
    @State private var glowScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0.4

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            backgroundGlow

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    crownSection
                    textSection
                    proBadge
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 40)
                .scaleEffect(appeared ? 1 : 0.92)

                Spacer()

                ctaButton
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.15).delay(0.2)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowScale = 1.15
                glowOpacity = 0.6
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private var backgroundGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.green.opacity(0.12),
                    Color.purple.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3, y: 0.35),
                startRadius: 10,
                endRadius: 200
            )

            RadialGradient(
                colors: [
                    Color.green.opacity(0.08),
                    Color.clear
                ],
                center: UnitPoint(x: 0.7, y: 0.6),
                startRadius: 10,
                endRadius: 180
            )
        }
        .ignoresSafeArea()
    }

    private var crownSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.yellow.opacity(0.15),
                            Color.orange.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(glowScale)

            Image(systemName: "crown.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.85, blue: 0.3),
                            Color(red: 0.95, green: 0.65, blue: 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.4), radius: 20, y: 8)
        }
    }

    private var textSection: some View {
        VStack(spacing: 12) {
            Text("Welcome to Fit AI Pro")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("You've unlocked advanced physique analysis,\nelite tracking, and AI-powered coaching.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    private var proBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.3))
            Text("Pro Activated")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.3))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.1)
        )
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .strokeBorder(
                    Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    private var ctaButton: some View {
        Button(action: onContinue) {
            Text("Start My Journey")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .sensoryFeedback(.impact(weight: .medium), trigger: true)
    }
}
