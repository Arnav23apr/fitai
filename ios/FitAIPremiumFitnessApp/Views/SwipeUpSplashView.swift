import SwiftUI

/// Welcome splash that mirrors the marketing site (`ios/docs/index.html`).
///
/// Pre-swipe: a hint to drag the dumbbell up into a scan-frame target. The
/// dumbbell uses the same procedural geometry as the website (built in
/// `DumbbellSceneView`) so first-touch parity with the landing page.
///
/// Post-swipe ("placed"): floating plate field + particle dust fade in
/// behind the dumbbell, the stacked `Scan. / Plan. / Compete.` headline
/// reveals (with `Plan.` dimmed and overlapped by the dumbbell), the
/// AI-Powered Fitness pill + subtitle + CTA come up. Identical composition
/// to the website hero.
struct SwipeUpSplashView: View {
    var onFinished: () -> Void
    var onLogin: (() -> Void)?

    @Environment(AppState.self) private var appState

    @State private var appeared:           Bool    = false
    @State private var isDragging:         Bool    = false
    @State private var placed:             Bool    = false
    @State private var contentVisible:     Bool    = false
    @State private var nearThreshold:      Bool    = false
    @State private var showLanguagePicker: Bool    = false

    // Particle simulation state — bound to ParticleDumbbellView. Drag updates
    // `dragProgress`; threshold release schedules a multi-stage morph
    // sequence (Scan. → Plan. → Compete. → dumbbell-high) via
    // `sequenceWorkItems`, each tap-cancellable.
    @State private var particleStage: ParticleStage = .assembling
    @State private var dragProgress:  CGFloat       = 0
    @State private var sequenceWorkItems: [DispatchWorkItem] = []

    private var lang: String { appState.profile.selectedLanguage }

    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let impactMed    = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let selection    = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            let sw = geo.size.width
            let sh = geo.size.height
            let safeBottom = geo.safeAreaInsets.bottom
            let safeTop = geo.safeAreaInsets.top

            let frameCenterY: CGFloat = sh * 0.42
            let frameSize: CGFloat = 200

            ZStack {
                // ── Z0: black canvas ─────────────────────────────────────────
                Color.black.ignoresSafeArea()

                // ── Z2: scan frame target ────────────────────────────────────
                scanFrameView(size: frameSize)
                    .position(x: sw / 2, y: frameCenterY)
                    .opacity(contentVisible ? 0.55 : (appeared ? 0.16 : 0))
                    .zIndex(2)

                // ── Z3: dimmed "Plan." word (sits BEHIND the dumbbell) ───────
                // Web uses class="dim" on this — we render it as a separate
                // view at low z-index so the dumbbell visually overlaps it.
                if contentVisible {
                    Text("Plan.")
                        .font(.system(size: 100, weight: .black))
                        .tracking(-3)
                        .foregroundStyle(.white.opacity(0.62))
                        .position(x: sw / 2, y: frameCenterY)
                        .zIndex(3)
                        .transition(.opacity)
                }

                // ── Z4: particle-forge dumbbell (full splash) ───────────────
                // Single full-screen MTKView, particle-only — handles all
                // states (assemble, idle, burst, morph through Scan/Plan/
                // Compete, final reform). See `ParticleDumbbellView`.
                ParticleDumbbellView(stage: $particleStage,
                                       dragProgress: $dragProgress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(appeared ? 1 : 0)
                    .zIndex(4)

                // ── Z5: "Scan." (above) and "Compete." (below) headline ──────
                if contentVisible {
                    Text("Scan.")
                        .font(.system(size: 72, weight: .black))
                        .tracking(-3)
                        .foregroundStyle(.white)
                        .position(x: sw / 2, y: frameCenterY - frameSize / 2 - 40)
                        .zIndex(5)
                        .transition(.opacity.combined(with: .offset(y: 12)))

                    Text("Compete.")
                        .font(.system(size: 72, weight: .black))
                        .tracking(-3)
                        .foregroundStyle(.white)
                        .position(x: sw / 2, y: frameCenterY + frameSize / 2 + 40)
                        .zIndex(5)
                        .transition(.opacity.combined(with: .offset(y: -12)))
                }

                // ── Z6: AI-Powered Fitness pill (above Scan.) ────────────────
                if contentVisible {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.white.opacity(0.85))
                            .frame(width: 5, height: 5)
                        Text("AI-Powered Fitness")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(0.2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
                    .position(x: sw / 2, y: frameCenterY - frameSize / 2 - 100)
                    .zIndex(6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // ── Z7: top bar (FitAI logo left, language right) ────────────
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("FitAI")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .tracking(-0.4)
                    }
                    .opacity(contentVisible ? 1 : (appeared ? 0.45 : 0))

                    Spacer()

                    Button { showLanguagePicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 13, weight: .medium))
                            Text(currentFlag).font(.system(size: 16))
                        }
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white.opacity(0.06), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .allowsHitTesting(contentVisible)
                }
                .padding(.horizontal, 22)
                .padding(.top, safeTop > 0 ? 8 : 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(7)

                // ── Z8: subtitle + CTA + footer ──────────────────────────────
                VStack(spacing: 16) {
                    Spacer()

                    if contentVisible {
                        Text("Upload a photo. Get a plan built for your\nbody. Climb the global leaderboard.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 32)
                            .transition(.opacity)
                    }

                    Button {
                        impactHeavy.impactOccurred()
                        onFinished()
                    } label: {
                        Text("Get Started")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white)
                            .clipShape(.rect(cornerRadius: 28))
                    }
                    .padding(.horizontal, 24)

                    Button {
                        onLogin?() ?? onFinished()
                    } label: {
                        Text("Already have an account? **Log In**")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.50))
                    }

                    Text("Free 3-day trial · No credit card")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.32))
                        .padding(.bottom, safeBottom + 14)
                }
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 22)
                .zIndex(8)
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
                                    // 220pt of drag = full burst.
                                    let p = max(0, min(1.0, -dy / 220))

                                    if !isDragging {
                                        isDragging = true
                                        impactMed.impactOccurred()
                                        particleStage = .bursting
                                    }
                                    dragProgress = p

                                    if Int(abs(dy)) % 50 < 3 && abs(dy) > 30 {
                                        selection.selectionChanged()
                                    }

                                    if p > 0.55 && !nearThreshold {
                                        nearThreshold = true
                                        impactHeavy.impactOccurred()
                                    } else if p < 0.40 && nearThreshold {
                                        nearThreshold = false
                                    }
                                }
                                .onEnded { value in
                                    isDragging = false
                                    nearThreshold = false
                                    let velocity = value.predictedEndTranslation.height
                                    if dragProgress > 0.50 || velocity < -700 {
                                        triggerPlace()
                                    } else {
                                        impactLight.impactOccurred()
                                        particleStage = .idle
                                        withAnimation(.spring(response: 0.5,
                                                                dampingFraction: 0.78)) {
                                            dragProgress = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(10)
                }
            }
            .overlay {
                // Tap-to-skip during the morph sequence (after triggerPlace
                // but before content reveal). Single tap cancels remaining
                // stages and jumps to idleFinal + reveals content.
                if placed && !contentVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { skipSequence() }
                        .zIndex(12)
                }
            }
            .overlay {
                if !placed {
                    SwipeHintView()
                        .position(x: sw / 2,
                                   y: sh - safeBottom - 320)
                        .opacity(appeared && !isDragging ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isDragging)
                        .allowsHitTesting(false)
                        .zIndex(11)
                }
            }
        }
        .preferredColorScheme(.dark)
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

    /// Schedule the morph sequence after the user crosses the swipe-up
    /// threshold. Each stage transition is a DispatchWorkItem so a tap can
    /// cancel the rest of the chain via `skipSequence()`.
    ///
    /// Sequence: morphScan → holdScan → morphPlan → holdPlan →
    /// morphCompete → holdCompete → morphFinal → idleFinal (content reveal).
    /// Total ~3.6s. Subtle haptic on each word lock-in.
    private func triggerPlace() {
        impactHeavy.impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) { dragProgress = 0 }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            placed = true
        }

        // Durations match ParticleStage.morphDuration in the renderer.
        // Holds at 0.90s give the eye time to absorb each word; tap-to-skip
        // is still wired up if the user wants to bypass the cycle.
        let morphDur:  TimeInterval = 0.75
        let holdDur:   TimeInterval = 0.90
        let finalDur:  TimeInterval = 0.95

        var elapsed: TimeInterval = 0
        sequenceWorkItems.removeAll()

        schedule(after: elapsed) {
            particleStage = .morphScan
        }
        elapsed += morphDur
        schedule(after: elapsed) {
            particleStage = .holdScan
            selection.selectionChanged()
        }
        elapsed += holdDur
        schedule(after: elapsed) {
            particleStage = .morphPlan
        }
        elapsed += morphDur
        schedule(after: elapsed) {
            particleStage = .holdPlan
            selection.selectionChanged()
        }
        elapsed += holdDur
        schedule(after: elapsed) {
            particleStage = .morphCompete
        }
        elapsed += morphDur
        schedule(after: elapsed) {
            particleStage = .holdCompete
            selection.selectionChanged()
        }
        elapsed += holdDur
        schedule(after: elapsed) {
            particleStage = .morphFinal
            impactMed.impactOccurred()
        }
        elapsed += finalDur
        schedule(after: elapsed) {
            particleStage = .idleFinal
            notification.notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.55)) {
                contentVisible = true
            }
        }
    }

    private func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        let work = DispatchWorkItem(block: action)
        sequenceWorkItems.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Cancel any pending morph stages and jump straight to the final
    /// dumbbell + content reveal. Hooked up to a tap during the sequence.
    private func skipSequence() {
        guard placed && !contentVisible else { return }
        sequenceWorkItems.forEach { $0.cancel() }
        sequenceWorkItems.removeAll()
        impactLight.impactOccurred()
        particleStage = .idleFinal
        notification.notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.4)) {
            contentVisible = true
        }
    }

    // MARK: - Scan frame (corner brackets)

    private func scanFrameView(size: CGFloat) -> some View {
        let len: CGFloat = 30
        let thick: CGFloat = 1.8
        let color = Color.white.opacity(0.42)
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
        VStack(spacing: 8) {
            Image(systemName: "chevron.up")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .offset(y: bounce)
            Text("Drag up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .tracking(0.6)
                .textCase(.uppercase)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                bounce = -8
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) {
                opacity = 0.78
            }
        }
    }
}
