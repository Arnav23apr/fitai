import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
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
                    .frame(width: 100, height: 100)
                    .clipShape(.rect(cornerRadius: 24))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                VStack(spacing: 12) {
                    Text("Transform Your")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                    Text("Physique with AI")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                }
                .foregroundStyle(.primary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Text("Your personal AI fitness coach.\nScan, plan, and compete.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.system(.headline, design: .default, weight: .bold))
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(.rect(cornerRadius: 28))
                }

                Button(action: { onLogin?() ?? onContinue() }) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(.secondary)
                        Text("Sign In")
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            HStack(spacing: 4) {
                Text("By continuing you agree to our")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button("Terms") {}
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("and")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button("Privacy Policy") {}
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
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
            .navigationTitle("Language")
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
