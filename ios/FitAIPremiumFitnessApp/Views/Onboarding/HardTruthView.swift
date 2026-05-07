import SwiftUI

struct HardTruthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var appeared: Bool = false
    @State private var bodyAppeared: Bool = false
    @State private var ctaAppeared: Bool = false
    /// Bumped on tap so `.sensoryFeedback` fires on press, not appearance.
    @State private var ctaTapCount: Int = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private var statBody: String {
        switch appState.profile.primaryGoal {
        case "Build Muscle": return L.t("hardTruthMuscle", lang)
        case "Lose Fat":     return L.t("hardTruthFat", lang)
        case "Recomp":       return L.t("hardTruthRecomp", lang)
        default:             return L.t("hardTruthDefault", lang)
        }
    }

    private var sourceLine: String {
        switch appState.profile.primaryGoal {
        case "Build Muscle": return L.t("hardTruthSourceMuscle", lang)
        case "Lose Fat":     return L.t("hardTruthSourceFat", lang)
        case "Recomp":       return L.t("hardTruthSourceRecomp", lang)
        default:             return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                Text(L.t("hardTruthTitle", lang))
                    .font(.system(size: 44, weight: .black, design: .default))
                    .tracking(-1)
                    .foregroundStyle(.primary)
                    .opacity(appeared ? 1 : 0)
                    .blur(radius: appeared ? 0 : 8)
                    .scaleEffect(appeared ? 1 : 1.04, anchor: .leading)

                Text(statBody)
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(4)
                    .opacity(bodyAppeared ? 1 : 0)
                    .blur(radius: bodyAppeared ? 0 : 5)
                    .offset(y: bodyAppeared ? 0 : 14)

                if !sourceLine.isEmpty {
                    Text(sourceLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .opacity(bodyAppeared ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)

            Spacer()

            Button {
                ctaTapCount += 1
                onContinue()
            } label: {
                Text(L.t("imReady", lang))
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
            // Layered haptics: light tick when title lands, medium when body
            // arrives, heavy thump on press — gives the page a felt rhythm.
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: appeared)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.6), trigger: bodyAppeared)
            .sensoryFeedback(.impact(weight: .heavy), trigger: ctaTapCount)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.1)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.65)) {
                bodyAppeared = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.74).delay(1.25)) {
                ctaAppeared = true
            }
        }
    }
}
