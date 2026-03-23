import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    var onLogin: (() -> Void)?

    @State private var appeared      = false
    @State private var floatY: CGFloat = 0
    @State private var scanProgress: CGFloat = 0
    @State private var bracketOpacity: Double = 1.0
    @State private var showLanguagePicker = false

    private var lang: String { appState.profile.selectedLanguage }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Ambient particles
            particleLayer.ignoresSafeArea()

            VStack(spacing: 0) {

                // Language picker button
                HStack {
                    Spacer()
                    Button { showLanguagePicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .medium))
                            Text(currentFlag).font(.system(size: 17))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)
                .opacity(appeared ? 1 : 0)

                Spacer()

                // Dumbbell + scan brackets
                ZStack {
                    scanBracketsView
                    dumbbellView
                        .offset(y: floatY)
                }
                .frame(width: 280, height: 160)
                .opacity(appeared ? 1 : 0)

                // Headline
                VStack(spacing: 14) {
                    VStack(alignment: .center, spacing: -6) {
                        Text("Scan.")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-2)
                        Text("Plan.")
                            .font(.system(size: 58, weight: .thin))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(-2)
                        Text("Compete.")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-2)
                    }

                    // AI badge
                    HStack(spacing: 7) {
                        BlinkingDot()
                        Text("AI-Powered Fitness")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(0.8)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.white.opacity(0.07))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.top, 36)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()
                Spacer()

                // CTA
                VStack(spacing: 14) {
                    Button(action: onContinue) {
                        Text(L.t("getStarted", lang))
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color.white)
                            .clipShape(.rect(cornerRadius: 28))
                    }

                    Button(action: { onLogin?() ?? onContinue() }) {
                        Text("\(L.t("alreadyHaveAccount", lang)) **\(L.t("logIn", lang))**")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
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
                .padding(.top, 12).padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                floatY = -13
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.6)) {
                scanProgress = 1
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bracketOpacity = 0.45
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    // MARK: - Dumbbell

    private var dumbbellView: some View {
        HStack(spacing: 0) {
            // Left plates
            HStack(spacing: 2) {
                weightPlate(width: 15, height: 58)
                weightPlate(width: 12, height: 46)
            }
            collarView
            barSegment(width: 38)
            gripView
            barSegment(width: 38)
            collarView
            // Right plates
            HStack(spacing: 2) {
                weightPlate(width: 12, height: 46)
                weightPlate(width: 15, height: 58)
            }
        }
    }

    private func weightPlate(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: width, height: height)
    }

    private var collarView: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.55))
            .frame(width: 7, height: 20)
            .padding(.horizontal, 1)
    }

    private func barSegment(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.82))
            .frame(width: width, height: 8)
    }

    private var gripView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.28))
                .frame(width: 30, height: 13)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 1.5, height: 10)
                }
            }
        }
    }

    // MARK: - Scan Brackets

    private var scanBracketsView: some View {
        let bracketLen: CGFloat = 22
        let bracketThick: CGFloat = 1.5
        let color = Color.white

        return ZStack {
            // Four corners
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Top-left
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: false, flipV: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // Top-right
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: true, flipV: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                    // Bottom-left
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: false, flipV: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                    // Bottom-right
                    cornerBracket(len: bracketLen, thick: bracketThick, color: color, flipH: true, flipV: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                    // Scan line
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.55), .clear],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1.5)
                        .offset(y: (scanProgress - 0.5) * h)
                }
                .frame(width: w, height: h)
            }
        }
        .opacity(bracketOpacity)
    }

    private func cornerBracket(len: CGFloat, thick: CGFloat, color: Color, flipH: Bool, flipV: Bool) -> some View {
        ZStack(alignment: flipH ? (flipV ? .bottomTrailing : .topTrailing) : (flipV ? .bottomLeading : .topLeading)) {
            Rectangle().fill(color.opacity(0.55))
                .frame(width: len, height: thick)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: flipH ? (flipV ? .bottomTrailing : .topTrailing) : (flipV ? .bottomLeading : .topLeading))
            Rectangle().fill(color.opacity(0.55))
                .frame(width: thick, height: len)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: flipH ? (flipV ? .bottomTrailing : .topTrailing) : (flipV ? .bottomLeading : .topLeading))
        }
        .frame(width: len, height: len)
    }

    // MARK: - Particles

    private var particleLayer: some View {
        let positions: [(Double, Double, Double, Double)] = [
            (0.10, 0.18, 0.0, 1.4), (0.88, 0.12, 1.3, 1.1),
            (0.04, 0.50, 2.2, 1.8), (0.94, 0.60, 0.7, 1.3),
            (0.22, 0.82, 1.8, 1.0), (0.75, 0.86, 3.1, 1.6),
            (0.48, 0.06, 0.4, 1.5), (0.62, 0.94, 2.7, 1.2),
            (0.14, 0.70, 1.5, 0.9), (0.82, 0.35, 2.4, 1.7),
            (0.35, 0.25, 3.3, 1.1), (0.68, 0.55, 0.9, 1.3),
        ]
        return TimelineView(.animation(minimumInterval: 1.0/30.0)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for (px, py, phase, r) in positions {
                    let x = px * size.width
                    let y = py * size.height + sin(t * 0.45 + phase) * 7
                    let alpha = (sin(t * 0.7 + phase) + 1) / 2 * 0.14 + 0.04
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
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

    // MARK: - Language Picker Sheet (unchanged)

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
                            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Color(.systemGray5) : Color.clear))
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
