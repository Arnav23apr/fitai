import SwiftUI

struct WelcomeProView: View {
    var onContinue: () -> Void

    @State private var appeared: Bool = false
    @State private var glowScale: CGFloat = 0.88
    @State private var glowOpacity: Double = 0.5
    @State private var haloRotation: Double = 0
    @State private var pressed: Bool = false

    private let champagne = Color(red: 1.00, green: 0.92, blue: 0.66)
    private let gold      = Color(red: 1.00, green: 0.78, blue: 0.32)
    private let amber     = Color(red: 0.86, green: 0.56, blue: 0.16)
    private let warmWhite = Color(red: 1.00, green: 0.97, blue: 0.92)

    private let features: [(icon: String, label: String)] = [
        ("sparkles",          "Advanced physique analysis"),
        ("chart.line.uptrend.xyaxis", "Elite progress tracking"),
        ("brain.head.profile", "AI-powered coaching"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            backgroundGlow

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(spacing: 36) {
                    crownSection
                    headlineSection
                    featuresSection
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 32)
                .scaleEffect(appeared ? 1 : 0.94)

                Spacer()

                ctaButton
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.18).delay(0.15)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glowScale = 1.20
                glowOpacity = 0.72
            }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                haloRotation = 360
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private var backgroundGlow: some View {
        ZStack {
            RadialGradient(
                colors: [gold.opacity(0.22), amber.opacity(0.10), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 380
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)

            RadialGradient(
                colors: [champagne.opacity(0.07), .clear],
                center: UnitPoint(x: 0.5, y: 0.30),
                startRadius: 20,
                endRadius: 220
            )
        }
        .ignoresSafeArea()
        .blendMode(.screen)
    }

    private var crownSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [gold.opacity(0.28), amber.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 90
                    )
                )
                .frame(width: 168, height: 168)
                .scaleEffect(glowScale)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            gold.opacity(0.55), gold.opacity(0.05),
                            gold.opacity(0.55), gold.opacity(0.05),
                            gold.opacity(0.55),
                        ],
                        center: .center
                    ),
                    lineWidth: 0.75
                )
                .frame(width: 156, height: 156)
                .rotationEffect(.degrees(haloRotation))

            Circle()
                .strokeBorder(gold.opacity(0.10), lineWidth: 0.5)
                .frame(width: 132, height: 132)

            Image(systemName: "crown.fill")
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [champagne, gold, amber],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: gold.opacity(0.55), radius: 24, y: 8)
                .shadow(color: amber.opacity(0.30), radius: 6, y: 2)
        }
        .frame(height: 168)
    }

    private var headlineSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                hairline
                Text("PRO ACTIVATED")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(3.5)
                    .foregroundStyle(gold)
                hairline
            }
            .frame(maxWidth: 220)

            VStack(spacing: 2) {
                Text("Welcome to")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Fit AI Pro")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(warmWhite)
            }
        }
    }

    private var hairline: some View {
        LinearGradient(
            colors: [.clear, gold.opacity(0.5), gold.opacity(0.5), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.5)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.label) { item in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(gold.opacity(0.35), lineWidth: 0.75)
                            .background(
                                Circle()
                                    .fill(gold.opacity(0.06))
                            )
                            .frame(width: 26, height: 26)
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(gold)
                    }
                    Text(item.label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private var ctaButton: some View {
        Button {
            onContinue()
        } label: {
            HStack(spacing: 10) {
                Text("Start My Journey")
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [champagne, gold, amber],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                }
            )
            .shadow(color: gold.opacity(0.45), radius: 24, y: 10)
            .shadow(color: amber.opacity(0.20), radius: 6, y: 2)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .sensoryFeedback(.impact(weight: .medium), trigger: pressed)
    }
}
