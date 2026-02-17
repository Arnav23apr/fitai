import SwiftUI

struct LanguageSelectionView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var appeared: Bool = false
    @State private var selectedLanguage: String = "English"

    private let languages: [(name: String, flag: String, native: String)] = [
        ("English", "🇺🇸", "English"),
        ("Arabic", "🇸🇦", "العربية"),
        ("Chinese", "🇨🇳", "中文"),
        ("Dutch", "🇳🇱", "Nederlands"),
        ("French", "🇫🇷", "Français"),
        ("German", "🇩🇪", "Deutsch"),
        ("Hebrew", "🇮🇱", "עברית"),
        ("Hindi", "🇮🇳", "हिन्दी"),
        ("Italian", "🇮🇹", "Italiano"),
        ("Japanese", "🇯🇵", "日本語"),
        ("Korean", "🇰🇷", "한국어"),
        ("Polish", "🇵🇱", "Polski"),
        ("Portuguese", "🇧🇷", "Português"),
        ("Romanian", "🇷🇴", "Română"),
        ("Russian", "🇷🇺", "Русский"),
        ("Spanish", "🇪🇸", "Español"),
        ("Swedish", "🇸🇪", "Svenska"),
        ("Turkish", "🇹🇷", "Türkçe"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("🌍")
                    .font(.system(size: 48))
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.5)

                Text("Choose Your Language")
                    .font(.system(.title2, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(languages.enumerated()), id: \.element.name) { index, language in
                        let isSelected = selectedLanguage == language.name
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedLanguage = language.name
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.system(size: 28))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.native)
                                        .font(.system(.body, design: .default, weight: .semibold))
                                        .foregroundStyle(.white)

                                    if language.native != language.name {
                                        Text(language.name)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.03), value: appeared)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            Button {
                appState.profile.selectedLanguage = selectedLanguage
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
        }
        .onAppear {
            selectedLanguage = appState.profile.selectedLanguage
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
