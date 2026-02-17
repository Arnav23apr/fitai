import SwiftUI

struct GenderView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    private var options: [(icon: String, key: String, value: String)] {
        [
            ("figure.stand", "male", "Male"),
            ("figure.stand.dress", "female", "Female"),
            ("dumbbell.fill", "gymRat", "GymRat")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("whatsYourGender", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(L.t("gender", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
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
                                .font(.system(size: 22))
                                .foregroundStyle(selected == option.value ? .black : .white.opacity(0.6))
                                .frame(width: 32)
                            Text(L.t(option.key, lang))
                                .font(.headline)
                                .foregroundStyle(selected == option.value ? .black : .white)
                            Spacer()
                            if selected == option.value {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 60)
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
                appState.profile.gender = selected
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
