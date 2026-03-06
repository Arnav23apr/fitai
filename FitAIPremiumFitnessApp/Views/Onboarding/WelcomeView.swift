import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    var onLogin: (() -> Void)?
    @State private var appeared: Bool = false
    @State private var showLanguagePicker: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

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

    private var isDark: Bool { colorScheme == .dark }

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
                    .background(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    .clipShape(Capsule())
                }
                .foregroundStyle(isDark ? .white.opacity(0.8) : .black.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 24) {
                Image(isDark ? "FitAILogoWhite" : "FitAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .clipShape(.rect(cornerRadius: 40))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(L.t("yourPersonalCoach", lang))
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                Text(L.t("scanPlanCompete", lang))
                    .font(.system(.title3, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text(L.t("getStarted", lang))
                        .font(.system(.headline, design: .default, weight: .bold))
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(.rect(cornerRadius: 28))
                }

                Button(action: { onLogin?() ?? onContinue() }) {
                    Text("\(L.t("alreadyHaveAccount", lang)) **\(L.t("logIn", lang))**")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isDark ? .white.opacity(0.6) : .black.opacity(0.5))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            HStack(spacing: 4) {
                Text(L.t("byContinuingAgree", lang))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button(L.t("terms", lang)) {}
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(L.t("and", lang))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button(L.t("privacyPolicy", lang)) {}
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .background(Color(.systemBackground))
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
            .navigationTitle(L.t("language", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("done", lang)) {
                        showLanguagePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
