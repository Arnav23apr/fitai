import SwiftUI

struct TrainingExperienceView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private let options: [(icon: String, titleKey: String, subtitleKey: String)] = [
        ("leaf", "Beginner", "Less than 6 months"),
        ("flame", "Intermediate", "6 months – 2 years"),
        ("bolt.fill", "Advanced", "2+ years of training"),
        ("trophy.fill", "Expert", "Competitive level")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(appState.t("Training"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.t("Experience"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.t("How long have you been training?"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 12) {
                ForEach(options, id: \.titleKey) { option in
                    let isSelected = selected == option.titleKey
                    Button {
                        selected = option.titleKey
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected ? .black : .white.opacity(0.5))
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.t(option.titleKey))
                                    .font(.headline)
                                    .foregroundStyle(isSelected ? .black : .white)
                                Text(appState.t(option.subtitleKey))
                                    .font(.caption)
                                    .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.4))
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 64)
                        .background(isSelected ? Color.white : Color.white.opacity(0.06))
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
                Text(appState.t("Continue"))
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
