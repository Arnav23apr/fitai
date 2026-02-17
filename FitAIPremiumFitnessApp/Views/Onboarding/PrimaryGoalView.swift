import SwiftUI

struct PrimaryGoalView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    private var options: [(icon: String, labelKey: String, descKey: String, value: String)] {
        [
            ("figure.strengthtraining.traditional", "buildMuscle", "gainSizeStrength", "Build Muscle"),
            ("flame.fill", "loseFat", "leanDownCut", "Lose Fat"),
            ("arrow.triangle.2.circlepath", "recomp", "buildMuscleLoseFat", "Recomp")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("primary", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(L.t("goal", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(L.t("whatsYourFocus", lang))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ForEach(options, id: \.value) { option in
                    Button {
                        selected = option.value
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selected == option.value ? .black : .white.opacity(0.5))
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t(option.labelKey, lang))
                                    .font(.headline)
                                    .foregroundStyle(selected == option.value ? .black : .white)
                                Text(L.t(option.descKey, lang))
                                    .font(.caption)
                                    .foregroundStyle(selected == option.value ? .black.opacity(0.6) : .white.opacity(0.4))
                            }
                            Spacer()
                            if selected == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 72)
                        .background(selected == option.value ? Color.white : Color.white.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()

            Button(action: {
                appState.profile.primaryGoal = selected
                onContinue()
            }) {
                Text(L.t("continue", lang))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected.isEmpty ? Color.white.opacity(0.3) : Color.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(selected.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
