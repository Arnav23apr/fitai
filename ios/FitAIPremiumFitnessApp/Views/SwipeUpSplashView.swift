import SwiftUI

struct SwipeUpSplashView: View {
    var onFinished: () -> Void
    var onLogin: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var appeared:           Bool    = false
    @State private var dragY:              CGFloat = 0
    @State private var isDragging:         Bool    = false
    @State private var placed:             Bool    = false
    @State private var contentVisible:     Bool    = false
    @State private var nearThreshold:      Bool    = false   // for escalating haptics
    @State private var showLanguagePicker: Bool    = false

    private var lang: String { appState.profile.selectedLanguage }

    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let impactMed    = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let selection    = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private let dbSize: CGFloat = 360

    var body: some View {
        GeometryReader { geo in
            let sw         = geo.size.width
            let sh         = geo.size.height
            let safeBottom = geo.safeAreaInsets.bottom

            let frameCenterY: CGFloat = sh * 0.38
            let frameSize:    CGFloat = 260
            let dbRestY:      CGFloat = sh - safeBottom - 8 - dbSize / 2
            let travelDist            = dbRestY - frameCenterY
            let progress: CGFloat     = travelDist > 0
                ? max(0, min(1.2, -dragY / travelDist)) : 0
            let dbCenterY: CGFloat    = placed ? frameCenterY : (dbRestY + dragY)

            ZStack(alignment: .top) {
                Color(.systemBackground).ignoresSafeArea()

                // ── Z1: Dumbbell — inverted color vs background ───────────────
                DumbbellSceneView(transparent: true, darkChrome: colorScheme == .light)
                    .frame(width: dbSize, height: dbSize)
                    .shadow(color: Color.primary.opacity(0.12), radius: 32, y: 14)
                    .allowsHitTesting(false)
                    .opacity(appeared ? 1 : 0)
                    .position(x: sw / 2, y: dbCenterY)
                    .zIndex(1)

                // ── Z2: Scan frame ────────────────────────────────────────────
                scanFrameView(size: frameSize)
                    .position(x: sw / 2, y: frameCenterY)
                    .opacity(contentVisible ? 1 : 0)
                    .zIndex(2)

                if contentVisible {
                    SplashSweepLine()
                        .frame(width: frameSize, height: frameSize)
                        .position(x: sw / 2, y: frameCenterY)
                        .zIndex(2)
                }

                // ── Z3: Headline text ─────────────────────────────────────────
                headlineText
                    .position(x: sw / 2, y: frameCenterY + frameSize / 2 + 76)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)
                    .zIndex(3)

                // ── Z4: Top bar — FitAI wordmark (left) + language picker (right) ──
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primary.opacity(0.72))
                        Text("FitAI")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(Color.primary)
                            .tracking(-0.4)
                    }

                    Spacer()

                    Button { showLanguagePicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 13, weight: .medium))
                            Text(currentFlag).font(.system(size: 16))
                        }
                        .foregroundStyle(Color.primary.opacity(0.72))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.13), lineWidth: 1))
                    }
                    .allowsHitTesting(contentVisible)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .top)
                .opacity(contentVisible ? 1 : 0)
                .zIndex(4)

                // ── Z5: Get Started + Login buttons ─────────────────────────
                VStack(spacing: 14) {
                    Spacer()
                    Button {
                        impactHeavy.impactOccurred()
                        onFinished()
                    } label: {
                        Text("Get Started")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.primary)
                            .clipShape(.rect(cornerRadius: 28))
                    }

                    Button {
                        onLogin?() ?? onFinished()
                    } label: {
                        Text("Already have an account? **Log In**")
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.50))
                    }

                    HStack(spacing: 4) {
                        Text(L.t("byContinuingAgree", lang))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.32))
                        Text(L.t("terms", lang))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.55))
                        Text(L.t("and", lang))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.32))
                        Text(L.t("privacyPolicy", lang))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.55))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, safeBottom + 14)
                }
                .padding(.horizontal, 24)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 22)
                .zIndex(5)

                // ── Z6: Swipe hint ────────────────────────────────────────────
                if !placed {
                    SwipeHintView()
                        .position(x: sw / 2, y: dbRestY - dbSize / 2 - 32)
                        .opacity(appeared && !isDragging ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isDragging)
                        .zIndex(6)
                }
            }
            .overlay {
                if !placed {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .gesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { value in
                                    let dy = min(0, value.translation.height)

                                    if !isDragging {
                                        isDragging = true
                                        impactMed.impactOccurred()
                                    }

                                    dragY = dy   // direct 1:1, no animation

                                    let p = travelDist > 0 ? -dy / travelDist : 0

                                    // Tick every ~50 pt
                                    if Int(abs(dy)) % 50 < 3 && abs(dy) > 30 {
                                        selection.selectionChanged()
                                    }

                                    // Escalate: medium tick when 60% of the way
                                    if p > 0.60 && !nearThreshold {
                                        nearThreshold = true
                                        impactMed.impactOccurred()
                                    } else if p < 0.40 && nearThreshold {
                                        nearThreshold = false
                                    }
                                }
                                .onEnded { value in
                                    isDragging = false
                                    nearThreshold = false
                                    let velocity = value.predictedEndTranslation.height
                                    if progress > 0.52 || velocity < -700 {
                                        triggerPlace()
                                    } else {
                                        // Light feedback — snapped back
                                        impactLight.impactOccurred()
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                                            dragY = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(10)
                }
            }
            .onChange(of: dragY) { _, _ in }
        }
        .onAppear {
            impactMed.prepare()
            impactHeavy.prepare()
            impactLight.prepare()
            selection.prepare()
            notification.prepare()
            withAnimation(.easeOut(duration: 0.55).delay(0.08)) { appeared = true }
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
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

    // MARK: - Snap to frame

    private func triggerPlace() {
        impactHeavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.notification.notificationOccurred(.success)
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            placed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.55)) {
                contentVisible = true
            }
        }
    }

    // MARK: - Scan frame

    private var headlineText: some View {
        VStack(alignment: .center, spacing: -4) {
            Text("Scan.")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Color.primary)
                .tracking(-2.5)
            Text("Plan.")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Color.primary.opacity(0.32))
                .tracking(-2.5)
            Text("Compete.")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Color.primary)
                .tracking(-2.5)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.62)
    }

    private func scanFrameView(size: CGFloat) -> some View {
        let len: CGFloat   = 30
        let thick: CGFloat = 1.8
        let color = Color.primary.opacity(0.45)
        return ZStack {
            cornerBracket(len: len, thick: thick, color: color, flipH: false, flipV: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerBracket(len: len, thick: thick, color: color, flipH: true,  flipV: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            cornerBracket(len: len, thick: thick, color: color, flipH: false, flipV: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            cornerBracket(len: len, thick: thick, color: color, flipH: true,  flipV: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: size, height: size)
    }

    private func cornerBracket(len: CGFloat, thick: CGFloat, color: Color,
                                flipH: Bool, flipV: Bool) -> some View {
        let align: Alignment = flipH
            ? (flipV ? .bottomTrailing : .topTrailing)
            : (flipV ? .bottomLeading  : .topLeading)
        return ZStack(alignment: align) {
            Rectangle().fill(color).frame(width: len, height: thick)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
            Rectangle().fill(color).frame(width: thick, height: len)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
        }
        .frame(width: len, height: len)
    }
}

// MARK: - Swipe hint

private struct SwipeHintView: View {
    @State private var bounce:  CGFloat = 0
    @State private var opacity: Double  = 1

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.38))
                .offset(y: bounce)
            Text("Swipe up")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.28))
                .tracking(0.2)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bounce = -6
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) {
                opacity = 0.45
            }
        }
    }
}

// MARK: - Sweep line (uses phased animation to avoid recursive DispatchQueue leaks)

private struct SplashSweepLine: View {
    @State private var phase: Int = 0
    private let cycleDuration: Double = 3.1  // total cycle length

    var body: some View {
        TimelineView(.periodic(from: .now, by: cycleDuration)) { timeline in
            GeometryReader { geo in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
                let progress = min(1, elapsed / 2.8)
                let opacity: Double = {
                    if elapsed < 0.18 { return elapsed / 0.18 * 0.9 }
                    if elapsed < 2.5 { return 0.9 }
                    if elapsed < 2.75 { return 0.9 * (1 - (elapsed - 2.5) / 0.25) }
                    return 0
                }()

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, Color.primary.opacity(0.45), .clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .offset(y: progress * geo.size.height)
                    .opacity(opacity)
            }
        }
    }
}
