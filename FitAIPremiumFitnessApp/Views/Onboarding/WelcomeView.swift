import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    var onLogin: (() -> Void)?

    @State private var appeared        = false
    @State private var scanProgress: CGFloat = 0
    @State private var bracketOpacity: Double = 1.0
    @State private var showLanguagePicker = false
    @State private var glassShimmer: CGFloat = -1.0   // for liquid-glass shimmer

    private var lang: String { appState.profile.selectedLanguage }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Metal background: noise + iridescent + scan glow + GPU particles ──
            WelcomeMetalView()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Language picker
                HStack {
                    Spacer()
                    Button { showLanguagePicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .medium))
                            Text(currentFlag).font(.system(size: 17))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 10)
                .opacity(appeared ? 1 : 0)

                Spacer()

                // ── 3-D Dumbbell (SceneKit / Metal) ──
                DumbbellSceneView()
                    .frame(width: 340, height: 200)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 32)

                // ── Headline with scan brackets overlaid ──
                ZStack {
                    scanBracketsView

                    VStack(spacing: 14) {
                        VStack(alignment: .center, spacing: -8) {
                            Text("Scan.")
                                .font(.system(size: 60, weight: .black))
                                .foregroundStyle(.white)
                                .tracking(-2)
                            Text("Plan.")
                                .font(.system(size: 60, weight: .thin))
                                .foregroundStyle(.white.opacity(0.40))
                                .tracking(-2)
                            Text("Compete.")
                                .font(.system(size: 60, weight: .black))
                                .foregroundStyle(.white)
                                .tracking(-2)
                        }

                        // AI badge
                        HStack(spacing: 7) {
                            BlinkingDot()
                            Text("AI-Powered Fitness")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()
                Spacer()

                // ── CTA ──
                VStack(spacing: 14) {
                    // Primary – Liquid Glass
                    Button(action: onContinue) {
                        ZStack {
                            // Shimmer sweep
                            GeometryReader { geo in
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.18), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geo.size.width * 0.5)
                                .offset(x: glassShimmer * geo.size.width * 1.5)
                                .clipped()
                            }
                            Text(L.t("getStarted", lang))
                                .font(.system(.headline, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.60),
                                            .white.opacity(0.15),
                                            .white.opacity(0.40)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.0
                                )
                        )
                    }

                    // Secondary – ghost text
                    Button(action: { onLogin?() ?? onContinue() }) {
                        Text("\(L.t("alreadyHaveAccount", lang)) **\(L.t("logIn", lang))**")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                // Legal
                HStack(spacing: 4) {
                    Text(L.t("byContinuingAgree", lang))
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.22))
                    Button(L.t("terms", lang)) {}
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.38))
                    Text(L.t("and", lang))
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.22))
                    Button(L.t("privacyPolicy", lang)) {}
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.38))
                }
                .padding(.top, 12).padding(.bottom, 18)
                .opacity(appeared ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }

            // Scan bracket pulse
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.4)) {
                scanProgress = 1
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bracketOpacity = 0.35
            }

            // Liquid glass shimmer loop
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false).delay(1.0)) {
                glassShimmer = 1.0
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    // MARK: - Scan Brackets (overlaid on text block)

    private var scanBracketsView: some View {
        let bracketLen: CGFloat  = 20
        let bracketThick: CGFloat = 1.5
        let color = Color.white

        return ZStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: false, flipV: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: true,  flipV: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: false, flipV: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: true,  flipV: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                    // Scan sweep line across the text
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.65), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                        .offset(y: (scanProgress - 0.5) * h)
                }
                .frame(width: w, height: h)
            }
        }
        .opacity(bracketOpacity)
    }

    private func cornerBracket(len: CGFloat, thick: CGFloat, color: Color,
                                flipH: Bool, flipV: Bool) -> some View {
        let align: Alignment = flipH
            ? (flipV ? .bottomTrailing : .topTrailing)
            : (flipV ? .bottomLeading  : .topLeading)
        return ZStack(alignment: align) {
            Rectangle().fill(color.opacity(0.60))
                .frame(width: len, height: thick)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
            Rectangle().fill(color.opacity(0.60))
                .frame(width: thick, height: len)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
        }
        .frame(width: len, height: len)
    }

    // MARK: - Helpers

    private var currentFlag: String {
        let langs: [(String, String)] = [
            ("English","🇺🇸"),("Arabic","🇸🇦"),("Chinese","🇨🇳"),("Dutch","🇳🇱"),
            ("French","🇫🇷"),("German","🇩🇪"),("Hebrew","🇮🇱"),("Hindi","🇮🇳"),
            ("Italian","🇮🇹"),("Japanese","🇯🇵"),("Korean","🇰🇷"),("Polish","🇵🇱"),
            ("Portuguese","🇧🇷"),("Romanian","🇷🇴"),("Russian","🇷🇺"),("Spanish","🇪🇸"),
            ("Swedish","🇸🇪"),("Turkish","🇹🇷"),
        ]
        return langs.first(where: { $0.0 == appState.profile.selectedLanguage })?.1 ?? "🇺🇸"
    }

    // MARK: - Language Picker Sheet

    private var languagePickerSheet: some View {
        let languages: [(name: String, flag: String, native: String)] = [
            ("English","🇺🇸","English"),("Arabic","🇸🇦","العربية"),("Chinese","🇨🇳","中文"),
            ("Dutch","🇳🇱","Nederlands"),("French","🇫🇷","Français"),("German","🇩🇪","Deutsch"),
            ("Hebrew","🇮🇱","עברית"),("Hindi","🇮🇳","हिन्दी"),("Italian","🇮🇹","Italiano"),
            ("Japanese","🇯🇵","日本語"),("Korean","🇰🇷","한국어"),("Polish","🇵🇱","Polski"),
            ("Portuguese","🇧🇷","Português"),("Romanian","🇷🇴","Română"),("Russian","🇷🇺","Русский"),
            ("Spanish","🇪🇸","Español"),("Swedish","🇸🇪","Svenska"),("Turkish","🇹🇷","Türkçe"),
        ]
        return NavigationStack {
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
                                Text(language.flag).font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.native)
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    if language.native != language.name {
                                        Text(language.name).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3).foregroundStyle(.green)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
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
                    Button(L.t("done", lang)) { showLanguagePicker = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - BlinkingDot

private struct BlinkingDot: View {
    @State private var opacity: Double = 1
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 5, height: 5)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    opacity = 0.2
                }
            }
    }
}
