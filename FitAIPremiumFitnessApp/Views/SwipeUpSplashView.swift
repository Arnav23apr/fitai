import SwiftUI

/// Swipe-up splash:
/// White screen. Scan corner brackets fixed in center. "Scan. Plan. Compete." text
/// below the brackets. 3D dumbbell at the bottom, rotating.
/// Swipe the dumbbell up — it travels through the scan grid (grid stays on top, creating
/// a "scanning" effect). Text fades as dumbbell passes. At threshold, snap-launch.
struct SwipeUpSplashView: View {
    var onFinished: () -> Void

    @State private var appeared: Bool = false
    @State private var dragY: CGFloat = 0          // ≤ 0 (upward only)
    @State private var isDragging: Bool = false
    @State private var completed: Bool = false
    @State private var scanActivated: Bool = false

    private let impactMed   = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection   = UISelectionFeedbackGenerator()

    private let dbSize: CGFloat = 300

    var body: some View {
        GeometryReader { geo in
            let sw = geo.size.width
            let sh = geo.size.height
            let safeBottom = geo.safeAreaInsets.bottom
            let safeTop    = geo.safeAreaInsets.top

            // ── Positions ──────────────────────────────────────────────
            // Dumbbell rests at the very bottom of the screen
            let dbRestY: CGFloat = sh - safeBottom - 40 - dbSize / 2

            // Current dumbbell center Y (moves upward with drag)
            let dbCenterY = dbRestY + dragY

            // Scan frame centered slightly above the middle
            let frameSize: CGFloat = 270
            let frameCenterY: CGFloat = sh * 0.36

            // 0 = at rest, 1 = dumbbell center is at scan frame center
            let travelDist = dbRestY - frameCenterY
            let progress: CGFloat = travelDist > 0 ? max(0, min(1.2, -dragY / travelDist)) : 0

            // ── Layout ─────────────────────────────────────────────────
            ZStack {
                Color.white.ignoresSafeArea()

                // ── Z1: 3D Dumbbell (moves, behind everything else) ────
                DumbbellSceneView(transparent: true)
                    .frame(width: dbSize, height: dbSize)
                    .allowsHitTesting(false)
                    .opacity(appeared ? 1 : 0)
                    .position(x: sw / 2, y: dbCenterY)
                    .zIndex(1)

                // ── Z2: Scan corner brackets (fixed center) ─────────────
                scanFrameView(size: frameSize)
                    .position(x: sw / 2, y: frameCenterY)
                    .opacity(appeared ? 1 : 0)
                    .zIndex(2)

                // Scan sweep line — activates when dumbbell enters frame
                if scanActivated {
                    SplashSweepLine()
                        .frame(width: frameSize, height: frameSize)
                        .position(x: sw / 2, y: frameCenterY)
                        .zIndex(2)
                }

                // ── Z3: "Scan. / Plan. / Compete." text ─────────────────
                // Sits just below the scan frame. Fades as dumbbell approaches.
                headlineText
                    .position(x: sw / 2, y: frameCenterY + frameSize / 2 + 62)
                    .opacity(appeared ? Double(max(0, 1 - progress * 1.8)) : 0)
                    .zIndex(3)

                // ── Z4: FitAI wordmark (top) ────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 7) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(white: 0.12))
                        Text("FitAI")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(Color(white: 0.08))
                            .tracking(-0.4)
                    }
                    .padding(.top, safeTop + 20)
                    .padding(.leading, 22)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(appeared ? 1 : 0)
                .zIndex(4)

                // ── Z4: Swipe hint ──────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 7) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(white: 0.42))
                        Text("Swipe up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(white: 0.42))
                    }
                    .padding(.bottom, safeBottom + dbSize + 24)
                }
                .opacity(appeared ? Double(max(0, 1 - progress * 5)) : 0)
                .zIndex(4)
            }
            // Drag gesture — on the whole view so user can start from anywhere near bottom
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        guard !completed else { return }
                        // Only track upward motion
                        let dy = min(0, value.translation.height)

                        if !isDragging {
                            isDragging = true
                            impactMed.impactOccurred()
                        }

                        // Direct 1:1 tracking while dragging
                        dragY = dy

                        // Activate scan when dumbbell enters the frame area
                        let p = travelDist > 0 ? -dy / travelDist : 0
                        if p > 0.42 && !scanActivated {
                            scanActivated = true
                            selection.selectionChanged()
                        } else if p < 0.25 && scanActivated {
                            scanActivated = false
                        }

                        // Subtle haptic ticks every ~50pt
                        if Int(abs(dy)) % 50 < 3 && abs(dy) > 30 {
                            selection.selectionChanged()
                        }
                    }
                    .onEnded { value in
                        guard !completed else { return }
                        isDragging = false

                        let velocity = value.predictedEndTranslation.height
                        let p = travelDist > 0 ? -dragY / travelDist : 0

                        if p > 0.52 || velocity < -700 {
                            triggerLaunch(dbRestY: dbRestY, sh: sh)
                        } else {
                            scanActivated = false
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
                                dragY = 0
                            }
                        }
                    }
            )
        }
        .onAppear {
            impactMed.prepare(); impactHeavy.prepare(); selection.prepare()
            withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Headline

    private var headlineText: some View {
        VStack(alignment: .center, spacing: -3) {
            Text("Scan.")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Color(white: 0.08))
                .tracking(-2.5)
            Text("Plan.")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Color(white: 0.08).opacity(0.38))
                .tracking(-2.5)
            Text("Compete.")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Color(white: 0.08))
                .tracking(-2.5)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.62)
    }

    // MARK: - Scan Frame (corner brackets only, no fill so dumbbell shows through)

    private func scanFrameView(size: CGFloat) -> some View {
        let len: CGFloat = 32
        let thick: CGFloat = 2.0
        let color = Color(white: 0.14).opacity(0.65)
        return ZStack {
            cornerBracket(len: len, thick: thick, color: color, flipH: false, flipV: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerBracket(len: len, thick: thick, color: color, flipH: true, flipV: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            cornerBracket(len: len, thick: thick, color: color, flipH: false, flipV: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            cornerBracket(len: len, thick: thick, color: color, flipH: true, flipV: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: size, height: size)
    }

    private func cornerBracket(len: CGFloat, thick: CGFloat, color: Color,
                                flipH: Bool, flipV: Bool) -> some View {
        let align: Alignment = flipH
            ? (flipV ? .bottomTrailing : .topTrailing)
            : (flipV ? .bottomLeading   : .topLeading)
        return ZStack(alignment: align) {
            Rectangle().fill(color).frame(width: len, height: thick)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
            Rectangle().fill(color).frame(width: thick, height: len)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
        }
        .frame(width: len, height: len)
    }

    // MARK: - Launch

    private func triggerLaunch(dbRestY: CGFloat, sh: CGFloat) {
        completed = true
        impactHeavy.impactOccurred()

        withAnimation(.spring(response: 0.40, dampingFraction: 0.76)) {
            dragY = -(dbRestY + 120)   // fly off screen top
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            onFinished()
        }
    }
}

// MARK: - Scan sweep line (self-contained, light mode)

private struct SplashSweepLine: View {
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, Color(white: 0.18).opacity(0.55), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .offset(y: progress * geo.size.height)
                .opacity(opacity)
        }
        .onAppear { animate() }
    }

    private func animate() {
        progress = 0; opacity = 0
        withAnimation(.easeIn(duration: 0.18)) { opacity = 0.9 }
        withAnimation(.easeInOut(duration: 2.8)) { progress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.25)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { animate() }
        }
    }
}
