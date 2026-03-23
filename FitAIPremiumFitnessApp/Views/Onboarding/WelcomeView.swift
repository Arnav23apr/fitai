import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    var onLogin: (() -> Void)?

    @State private var appeared        = false
    @State private var showLanguagePicker = false

    private var lang: String { appState.profile.selectedLanguage }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Near-black base (matches Metal shader bg_frag base color)
                Color(red: 0.028, green: 0.028, blue: 0.034)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Top bar: FitAI wordmark (left) + language picker (right) ──
                    topBar
                        .opacity(appeared ? 1 : 0)

                    // ── 3D Dumbbell hero scene ──
                    ZStack {
                        DumbbellSceneView()
                        // Scan frame centered inside the hero zone
                        scanFrame
                            .opacity(appeared ? 1 : 0)
                    }
                    .frame(height: geo.size.height * 0.42)

                    // ── Text content below ──
                    VStack(spacing: 0) {

                        // "AI-Powered Fitness" badge
                        aiBadge
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)

                        // Headline: Scan. / Plan. / Compete.
                        headlineText
                            .padding(.bottom, 14)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        // Subtitle
                        Text("Upload a photo. Get a plan built for\nyour body. Climb the global leaderboard.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 36)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                    }

                    Spacer()

                    // ── CTA ──
                    VStack(spacing: 14) {
                        Button(action: onContinue) {
                            Text(L.t("getStarted", lang))
                                .font(.system(.headline, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .clipShape(.rect(cornerRadius: 28))
                                .shadow(color: .white.opacity(0.10), radius: 48)
                        }

                        Button(action: { onLogin?() ?? onContinue() }) {
                            Text("\(L.t("alreadyHaveAccount", lang)) **\(L.t("logIn", lang))**")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.50))
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

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
                    .padding(.top, 10).padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            // FitAI wordmark
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.80))
                Text("FitAI")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
            }

            Spacer()

            // Language picker
            Button { showLanguagePicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .medium))
                    Text(currentFlag).font(.system(size: 16))
                }
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - AI Badge

    private var aiBadge: some View {
        HStack(spacing: 7) {
            BlinkingDot()
            Text("AI-Powered Fitness")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .tracking(0.3)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(.white.opacity(0.04), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
    }

    // MARK: - Headline

    private var headlineText: some View {
        VStack(alignment: .center, spacing: -6) {
            Text("Scan.")
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(.white)
                .tracking(-3)
            Text("Plan.")
                .font(.system(size: 68, weight: .thin))
                .foregroundStyle(.white.opacity(0.38))
                .tracking(-3)
            Text("Compete.")
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(.white)
                .tracking(-3)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 16)
    }

    // MARK: - Scan Frame (260pt, centered inside the hero zone)

    private var scanFrame: some View {
        let size: CGFloat = 240
        let len:  CGFloat = 24
        let thick: CGFloat = 1.5
        let color = Color.white.opacity(0.35)
        return ZStack {
            cornerBracket(len: len, thick: thick, color: color, flipH: false, flipV: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerBracket(len: len, thick: thick, color: color, flipH: true,  flipV: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            cornerBracket(len: len, thick: thick, color: color, flipH: false, flipV: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            cornerBracket(len: len, thick: thick, color: color, flipH: true,  flipV: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            ScanSweepLine()
        }
        .frame(width: size, height: size)
    }

    private func cornerBracket(len: CGFloat, thick: CGFloat, color: Color, flipH: Bool, flipV: Bool) -> some View {
        let align: Alignment = flipH ? (flipV ? .bottomTrailing : .topTrailing) : (flipV ? .bottomLeading : .topLeading)
        return ZStack(alignment: align) {
            Rectangle().fill(color).frame(width: len, height: thick)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
            Rectangle().fill(color).frame(width: thick, height: len)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
        }
        .frame(width: len, height: len)
    }

    // MARK: - Language helpers

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
                                    Text(language.native).font(.system(.body, weight: .semibold)).foregroundStyle(.primary)
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
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color(.systemGray5) : Color.clear))
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
                    Button(L.t("done", lang)) { showLanguagePicker = false }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Scan sweep line

private struct ScanSweepLine: View {
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.52), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .offset(y: progress * geo.size.height)
                .opacity(opacity)
        }
        .onAppear { animate() }
    }

    private func animate() {
        progress = 0; opacity = 0
        withAnimation(.easeInOut(duration: 0.22)) { opacity = 0.85 }
        withAnimation(.easeInOut(duration: 3.6)) { progress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { animate() }
        }
    }
}

// MARK: - BlinkingDot

private struct BlinkingDot: View {
    @State private var opacity: Double = 1
    var body: some View {
        Circle().fill(.white).frame(width: 5, height: 5).opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { opacity = 0.2 }
            }
    }
}
