import SwiftUI

struct TrainingExperienceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private var options: [(icon: String, titleKey: String, subtitleKey: String, value: String)] {
        [
            ("leaf", "beginner", "lessThan6Months", "Beginner"),
            ("flame", "intermediate", "sixMonthsTo2Years", "Intermediate"),
            ("bolt.fill", "advanced", "twoYearsPlus", "Advanced"),
            ("trophy.fill", "expert", "competitiveLevel", "Expert")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("training", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("experience", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("howLongTraining", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 12) {
                ForEach(options, id: \.value) { option in
                    Button {
                        selected = option.value
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selected == option.value ? (isDark ? .black : .white) : .secondary)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t(option.titleKey, lang))
                                    .font(.headline)
                                    .foregroundStyle(selected == option.value ? (isDark ? .black : .white) : .primary)
                                Text(L.t(option.subtitleKey, lang))
                                    .font(.caption)
                                    .foregroundStyle(selected == option.value ? (isDark ? Color.black.opacity(0.6) : Color.white.opacity(0.6)) : Color.secondary)
                            }
                            Spacer()
                            if selected == option.value {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(isDark ? .black : .white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 64)
                        .background(selected == option.value ? (isDark ? Color.white : Color.black) : (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.trainingExperience = selected
                onContinue()
            }) {
                Text(L.t("continue", lang))
                    .font(.headline)
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected.isEmpty ? (isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)) : (isDark ? Color.white : Color.black))
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
