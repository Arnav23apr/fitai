import SwiftUI

struct TrainingExperienceView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

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
                    .foregroundStyle(.white)
                Text(L.t("experience", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(L.t("howLongTraining", lang))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
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
                                .foregroundStyle(selected == option.value ? .black : .white.opacity(0.5))
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t(option.titleKey, lang))
                                    .font(.headline)
                                    .foregroundStyle(selected == option.value ? .black : .white)
                                Text(L.t(option.subtitleKey, lang))
                                    .font(.caption)
                                    .foregroundStyle(selected == option.value ? .black.opacity(0.6) : .white.opacity(0.4))
                            }
                            Spacer()
                            if selected == option.value {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 64)
                        .background(selected == option.value ? Color.white : Color.white.opacity(0.06))
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
