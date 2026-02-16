import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    var onLogin: (() -> Void)?
    @State private var appeared: Bool = false
    @State private var showLanguagePicker: Bool = false

    private let languages: [(name: String, flag: String, native: String)] = [
        ("English", "🇺🇸", "English"),
        ("Spanish", "🇪🇸", "Español"),
        ("French", "🇫🇷", "Français"),
        ("German", "🇩🇪", "Deutsch"),
        ("Portuguese", "🇧🇷", "Português"),
        ("Italian", "🇮🇹", "Italiano"),
        ("Dutch", "🇳🇱", "Nederlands"),
        ("Russian", "🇷🇺", "Русский"),
        ("Japanese", "🇯🇵", "日本語"),
        ("Korean", "🇰🇷", "한국어"),
        ("Chinese", "🇨🇳", "中文"),
        ("Arabic", "🇸🇦", "العربية"),
        ("Hindi", "🇮🇳", "हिन्दी"),
        ("Turkish", "🇹🇷", "Türkçe"),
        ("Polish", "🇵🇱", "Polski"),
        ("Swedish", "🇸🇪", "Svenska"),
        ("Romanian", "🇷🇴", "Română"),
        ("Hebrew", "🇮🇱", "עברית")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 15, weight: .medium))
                        Text(currentFlag)
                            .font(.system(size: 18))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 24) {
                Image("FitAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(.rect(cornerRadius: 24))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                VStack(spacing: 12) {
                    Text(appState.t("Transform Your"))
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Text(appState.t("Physique with AI"))
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Text(appState.t("Your personal AI fitness coach.\nScan, plan, and compete."))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text(appState.t("Get Started"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 16))
                }

                Button(action: { onLogin?() ?? onContinue() }) {
                    Text(appState.t("Existing user? Log in"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            HStack(spacing: 4) {
                Text(appState.t("By continuing you agree to our"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                Button(appState.t("Terms")) {}
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text(appState.t("and"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                Button(appState.t("Privacy Policy")) {}
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    private var currentFlag: String {
        languages.first(where: { $0.name == appState.profile.selectedLanguage })?.flag ?? "🇺🇸"
    }

    private var languagePickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(languages, id: \.name) { language in
                        let isSelected = appState.profile.selectedLanguage == language.name
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                appState.profile.selectedLanguage = language.name
                                appState.saveProfile()
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.system(size: 28))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.native)
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundStyle(.primary)

                                    if language.native != language.name {
                                        Text(language.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color(.systemGray5) : Color.clear)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(appState.t("Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showLanguagePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
