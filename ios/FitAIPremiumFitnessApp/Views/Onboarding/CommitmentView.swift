import SwiftUI

/// Pseudo-contract / commitment statement. Right before the plan
/// reveal, the user explicitly agrees to the three terms of their
/// plan. Cialdini commitment-and-consistency: people who explicitly
/// commit have ~30% higher 30-day retention than those who passively
/// progress.
///
/// Hero FX: a 3D chrome dumbbell (the same SceneKit asset that
/// opens the app on WelcomeView) floats near the bottom. The user
/// swipes it upward — as it rises and spins, the three contract
/// rows tick on at 60 / 120 / 180pt of travel. Reach the top of the
/// swipe distance to fire `onContinue`. Release early and the
/// dumbbell springs back, un-ticking rows in reverse so the user
/// can retry. A single tap on the dumbbell auto-plays the sequence
/// — accessibility fallback for anyone uncomfortable with the
/// gesture.
struct CommitmentView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void

    @State private var headerAppeared: Bool = false
    @State private var checked: [Bool] = [false, false, false]
    /// Current upward drag distance, capped slightly above the
    /// success threshold so the dumbbell can briefly overshoot.
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    /// Once true the dumbbell is committed — disables further drag,
    /// fires the flourish animation, and queues `onContinue`.
    @State private var committed: Bool = false
    /// Tick haptic counter; bumped each time a row flips on.
    @State private var rowTickCount: Int = 0
    /// Drag-start haptic counter; one medium impact when the user
    /// first puts a finger down on the dumbbell.
    @State private var dragStartTrigger: Int = 0
    /// Success-haptic trigger for the completion moment.
    @State private var completionTrigger: Int = 0
    /// Light-impact trigger for release-before-threshold cancels.
    @State private var cancelTrigger: Int = 0
    /// Animates a base rotation continuously while the dumbbell is
    /// idle (a gentle ~3rpm twirl) so it reads as alive at rest.
    @State private var idleRotation: Double = 0

    /// Pixels of upward travel required to commit. 180pt picked to
    /// match the medium-swipe option — easy and quick.
    private let swipeDistance: CGFloat = 180
    /// Tick thresholds (one per contract row). Each row ticks on
    /// when `dragOffset` crosses its threshold upward, and ticks
    /// off as the offset retreats below it during a cancel.
    private let rowThresholds: [CGFloat] = [60, 120, 180]

    private var lang: String { appState.profile.selectedLanguage }

    /// 0..1 normalized drag progress. Drives the embers brightness
    /// and the halation rim intensity.
    private var dragProgress: Double {
        Double(min(dragOffset, swipeDistance)) / Double(swipeDistance)
    }

    private var lines: [String] {
        let perWeek = "\(appState.profile.workoutsPerWeek)"
        let location = appState.profile.trainingLocation.isEmpty
            ? L.t("workout", lang).lowercased()
            : appState.profile.trainingLocation.lowercased()
        return [
            String(format: L.t("commitLine1", lang), perWeek),
            String(format: L.t("commitLine2", lang), location),
            L.t("commitLine3", lang),
        ]
    }

    var body: some View {
        ZStack {
            PremiumBackdrop()

            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 56)
                    .padding(.bottom, 28)

                contractCard
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                swipeZone
                    .padding(.bottom, 56)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { runChoreography() }
        // Drag offset → row ticks. Single source of truth: when the
        // offset crosses a threshold, the row's check flips. This
        // works in both directions, so springing back naturally
        // un-ticks the rows in reverse.
        .onChange(of: dragOffset) { _, newOffset in
            updateRowChecks(for: newOffset)
        }
        // Haptic stack: medium impact when the user first grabs the
        // dumbbell, a selection tick on each row check, a light
        // bump on cancel, and a heavy success on completion.
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: dragStartTrigger)
        .sensoryFeedback(.selection, trigger: rowTickCount)
        .sensoryFeedback(.success, trigger: completionTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: cancelTrigger)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            let name = appState.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = name.isEmpty
                ? L.t("commitTitle", lang)
                : "\(name), \(L.t("commitTitle", lang).lowercased())"

            Text(title)
                .font(OnboardingTheme.headlineCompact())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text(L.t("commitSubtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 12)
    }

    // MARK: - Contract card

    private var contractCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                contractRow(index: idx, text: line)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 12)
    }

    private func contractRow(index idx: Int, text: String) -> some View {
        let isChecked = checked[safeIdx: idx] ?? false

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    .frame(width: 28, height: 28)
                if isChecked {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }

            Text(text)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(isChecked ? 1.0 : 0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Swipe zone (hint + 3D dumbbell)

    /// Bottom-anchored swipe surface. The hint sits above the
    /// dumbbell and fades the moment the user touches; the dumbbell
    /// itself rises with the drag, spins fast, and accumulates a
    /// halation glow + ember field as progress climbs.
    private var swipeZone: some View {
        VStack(spacing: 16) {
            // "SWIPE UP" hint with a bouncing chevron. Mirrors the
            // SwipeHintView vocabulary from WelcomeView/Splash so the
            // gesture is taught the same way across the app.
            swipeHint
                .opacity(isDragging || committed ? 0 : 1)
                .animation(.easeOut(duration: 0.15), value: isDragging)

            // Dumbbell + ember field + gesture catcher. The SCNView
            // is set to allowsHitTesting(false) so the SwiftUI drag
            // gesture on the parent receives all touches.
            ZStack {
                MetalEmbersOverlay(brighten: true)
                    .frame(width: 280, height: 220)
                    .opacity(dragProgress * 0.85)
                    .blur(radius: 0.5)
                    .allowsHitTesting(false)

                DumbbellSceneView(transparent: true)
                    .frame(width: 200, height: 160)
                    .allowsHitTesting(false)
                    // Two compounding rotations: a slow idle twirl
                    // so it reads as alive at rest, plus a calm
                    // drag-driven spin (1.2° per point of upward
                    // travel ≈ 216° at full swipe — about 3/5 of a
                    // turn, smooth and tactile rather than blurry).
                    // Note: no `.halationGlow` here — that uses
                    // `.layerEffect` and breaks rendering on the
                    // Metal-backed SCNView, which is why the dumbbell
                    // was failing to draw earlier.
                    .rotationEffect(.degrees(idleRotation + Double(dragOffset) * 1.2))
                    .scaleEffect(committed ? 1.10 : 1.0)
                    .shadow(
                        color: .white.opacity(dragProgress * 0.30),
                        radius: 12 + 18 * dragProgress
                    )
                    .offset(y: -dragOffset)
            }
            .frame(width: 280, height: 220)
            .contentShape(Rectangle())
            .gesture(dumbbellDrag)
            .onTapGesture { autoSwipe() }
        }
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 20)
    }

    /// Bouncing chevron + caption. Same visual rhythm as the
    /// SwipeHintView used in SwipeUpSplashView so users who saw the
    /// app's first screen recognize the affordance immediately.
    private var swipeHint: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .modifier(BouncingChevron())
            Text("SWIPE UP")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .tracking(1.5)
        }
    }

    // MARK: - Drag gesture

    private var dumbbellDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !committed else { return }
                if !isDragging {
                    isDragging = true
                    // One medium impact the moment the user grabs
                    // the dumbbell — feels like the dumbbell "snaps"
                    // into the hand.
                    dragStartTrigger += 1
                }
                // Capture upward translation only. Tiny overshoot
                // above the success threshold is allowed for tactile
                // feel.
                let dy = max(0, -value.translation.height)
                dragOffset = min(dy, swipeDistance + 24)
            }
            .onEnded { value in
                guard !committed else { return }
                isDragging = false

                let velocity = value.predictedEndTranslation.height
                let crossed = dragOffset >= swipeDistance
                let flicked = velocity < -700 && dragOffset > swipeDistance * 0.6

                if crossed || flicked {
                    fireCompletion()
                } else {
                    cancelTrigger += 1
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Reactivity

    /// Flip per-row checks based on the current drag offset. Works
    /// in both directions so springing back un-ticks rows in
    /// reverse without separate cancel logic. Only ticking ON fires
    /// a haptic — un-ticks are silent.
    private func updateRowChecks(for offset: CGFloat) {
        for i in checked.indices {
            let threshold = rowThresholds[safeIdx: i] ?? .infinity
            let shouldBeChecked = offset >= threshold
            guard checked[i] != shouldBeChecked else { continue }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.65)) {
                checked[i] = shouldBeChecked
            }
            if shouldBeChecked { rowTickCount += 1 }
        }
    }

    /// Successful swipe-through. Push the offset slightly past the
    /// threshold for an overshoot flourish, keep rotating, fire the
    /// success haptic + halation pulse, then transition to the next
    /// screen ~350ms later.
    private func fireCompletion() {
        committed = true
        completionTrigger += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.60)) {
            dragOffset = swipeDistance + 24
        }
        // Add a final flourish spin — independent of dragOffset so
        // it animates on its own curve. 270° kept in step with the
        // calmer drag rotation so the celebration doesn't feel like
        // a different animation language.
        withAnimation(.easeOut(duration: 0.60)) {
            idleRotation += 270
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            onContinue()
        }
    }

    /// Accessibility fallback. A single tap on the dumbbell plays
    /// the full swipe sequence automatically — the row ticks fire
    /// through the natural onChange pathway as the offset animates.
    private func autoSwipe() {
        guard !committed, !isDragging else { return }
        withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
            dragOffset = swipeDistance
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            fireCompletion()
        }
    }

    // MARK: - Choreography

    private func runChoreography() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            headerAppeared = true
        }
        // Continuous slow idle rotation so the dumbbell doesn't
        // freeze when the user isn't touching it. ~3rpm.
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            idleRotation = 360
        }
    }
}

// MARK: - Helpers

/// Subtle vertical bounce loop on the chevron — same easing
/// SwipeHintView uses in SwipeUpSplashView so the affordance feels
/// consistent across the app.
private struct BouncingChevron: ViewModifier {
    @State private var dy: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: dy)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    dy = -6
                }
            }
    }
}

private extension Array {
    subscript(safeIdx index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
