import SwiftUI

struct OnePercentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var line1Appeared: Bool = false
    @State private var line2Appeared: Bool = false
    @State private var line3Appeared: Bool = false
    @State private var bodyAppeared: Bool = false
    @State private var ctaAppeared: Bool = false
    @State private var glowPulse: CGFloat = 0.85
    @State private var ctaTapCount: Int = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.primary.opacity(isDark ? 0.10 : 0.05),
                    Color.primary.opacity(0.0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 280
            )
            .scaleEffect(glowPulse)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("onePercentLine1", lang))
                        .opacity(line1Appeared ? 1 : 0)
                        .blur(radius: line1Appeared ? 0 : 6)
                        .offset(y: line1Appeared ? 0 : 16)
                    Text(L.t("onePercentLine2", lang))
                        .opacity(line2Appeared ? 1 : 0)
                        .blur(radius: line2Appeared ? 0 : 6)
                        .offset(y: line2Appeared ? 0 : 16)
                    Text(L.t("onePercentLine3", lang))
                        .opacity(line3Appeared ? 1 : 0)
                        .blur(radius: line3Appeared ? 0 : 6)
                        .offset(y: line3Appeared ? 0 : 16)
                }
                .font(.system(size: 36, weight: .black))
                .tracking(-0.8)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Text(L.t("onePercentBody", lang))
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .opacity(bodyAppeared ? 1 : 0)
                    .blur(radius: bodyAppeared ? 0 : 5)
                    .offset(y: bodyAppeared ? 0 : 12)

                Spacer()

                Button {
                    ctaTapCount += 1
                    onContinue()
                } label: {
                    Text(L.t("imIn", lang))
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.primary)
                        .clipShape(.rect(cornerRadius: 28))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(ctaAppeared ? 1 : 0)
                .scaleEffect(ctaAppeared ? 1 : 0.92)
                // Each line lands with its own light tap, body softer, CTA
                // press with a heavy thump. Stacked triggers on the button
                // is fine — each fires independently when its trigger flips.
                .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: line1Appeared)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: line2Appeared)
                .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: line3Appeared)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: bodyAppeared)
                .sensoryFeedback(.impact(weight: .heavy), trigger: ctaTapCount)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1)) {
                line1Appeared = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.55)) {
                line2Appeared = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.74).delay(1.0)) {
                line3Appeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(1.55)) {
                bodyAppeared = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(2.05)) {
                ctaAppeared = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPulse = 1.15
            }
        }
    }
}
