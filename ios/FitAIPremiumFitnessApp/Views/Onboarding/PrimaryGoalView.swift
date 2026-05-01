import SwiftUI

struct PrimaryGoalView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

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
                    .foregroundStyle(.primary)
                Text(L.t("goal", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("whatsYourFocus", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(selected == option.value ? Color(.systemBackground) : .secondary)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t(option.labelKey, lang))
                                    .font(.headline)
                                    .foregroundStyle(selected == option.value ? Color(.systemBackground) : .primary)
                                Text(L.t(option.descKey, lang))
                                    .font(.caption)
                                    .foregroundStyle(selected == option.value ? Color(.systemBackground).opacity(0.6) : Color.secondary)
                            }
                            Spacer()
                            if selected == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color(.systemBackground))
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 72)
                        .background(selected == option.value ? Color.primary : Color.primary.opacity(0.05))
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
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected.isEmpty ? Color.primary.opacity(0.3) : Color.primary)
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
