import SwiftUI

/// Splash screen flow:
/// 1. Dumbbell sits at the bottom, rotating. Apple-style swipe-up hint above it.
/// 2. User swipes dumbbell upward. 1:1 tracking, no rubber-banding.
/// 3. Threshold crossed → dumbbell spring-snaps to scan frame center.
/// 4. Scan brackets, "Scan. Plan. Compete." text, and "Get Started" button fade in.
/// 5. Tap "Get Started" → onFinished().
struct SwipeUpSplashView: View {
    var onFinished: () -> Void

    @State private var appeared:      Bool    = false
    @State private var dragY:         CGFloat = 0      // ≤ 0 (upward only)
    @State private var isDragging:    Bool    = false
    @State private var placed:        Bool    = false  // dumbbell locked at scan frame
    @State private var contentVisible: Bool   = false  // content revealed after placed

    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactMed   = UIImpactFeedbackGenerator(style: .medium)
    private let selection   = UISelectionFeedbackGenerator()

    private let dbSize: CGFloat = 300

    var body: some View {
        GeometryReader { geo in
            let sw         = geo.size.width
            let sh         = geo.size.height
            let safeBottom = geo.safeAreaInsets.bottom
            let safeTop    = geo.safeAreaInsets.top

            // ── Geometry ────────────────────────────────────────────────────
            let frameCenterY: CGFloat = sh * 0.38
            let frameSize:    CGFloat = 260
            let dbRestY:      CGFloat = sh - safeBottom - 16 - dbSize / 2
            let travelDist            = dbRestY - frameCenterY
            let progress: CGFloat     = travelDist > 0
                ? max(0, min(1.2, -dragY / travelDist)) : 0

            // Dumbbell Y: follows drag until placed, then locked at frameCenterY
            let dbCenterY: CGFloat = placed ? frameCenterY : (dbRestY + dragY)

            ZStack(alignment: .top) {

                // ── Background (follows system dark / light mode) ────────────
                Color(.systemBackground).ignoresSafeArea()

                // ── Z1: Dumbbell ─────────────────────────────────────────────
                DumbbellSceneView(transparent: true)
                    .frame(width: dbSize, height: dbSize)
                    .shadow(color: Color.primary.opacity(0.10), radius: 28, y: 12)
                    .allowsHitTesting(false)
                    .opacity(appeared ? 1 : 0)
                    .position(x: sw / 2, y: dbCenterY)
                    .zIndex(1)

                // ── Z2: Scan corner brackets ─────────────────────────────────
                scanFrameView(size: frameSize)
                    .position(x: sw / 2, y: frameCenterY)
                    .opacity(contentVisible ? 1 : 0)
                    .zIndex(2)

                // Sweep line inside brackets
                if contentVisible {
                    SplashSweepLine()
                        .frame(width: frameSize, height: frameSize)
                        .position(x: sw / 2, y: frameCenterY)
                        .zIndex(2)
                }

                // ── Z3: Headline text ────────────────────────────────────────
                headlineText
                    .position(x: sw / 2, y: frameCenterY + frameSize / 2 + 76)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)
                    .zIndex(3)

                // ── Z4: FitAI wordmark (top-left) ────────────────────────────
                HStack(spacing: 7) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.72))
                    Text("FitAI")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color.primary)
                        .tracking(-0.4)
                }
                .padding(.top, safeTop + 20)
                .padding(.leading, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(contentVisible ? 1 : 0)
                .zIndex(4)

                // ── Z5: Get Started button (bottom) ──────────────────────────
                VStack {
                    Spacer()
                    Button(action: { impactHeavy.impactOccurred(); onFinished() }) {
                        Text("Get Started")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.primary)
                            .clipShape(.rect(cornerRadius: 28))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, safeBottom + 20)
                }
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 22)
                .zIndex(5)

                // ── Z6: Swipe-up hint (only before placed) ───────────────────
                if !placed {
                    SwipeHintView()
                        .position(x: sw / 2, y: dbRestY - dbSize / 2 - 32)
                        .opacity(appeared && !isDragging ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: isDragging)
                        .zIndex(6)
                }
            }
            // Gesture overlay — removed after placement so buttons are tappable
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
                                    // Direct 1:1 tracking — no animation wrapper
                                    dragY = dy

                                    // Tick haptics every ~50 pt
                                    if Int(abs(dy)) % 50 < 3 && abs(dy) > 30 {
                                        selection.selectionChanged()
                                    }
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let velocity = value.predictedEndTranslation.height
                                    if progress > 0.52 || velocity < -700 {
                                        triggerPlace(dbRestY: dbRestY, travelDist: travelDist)
                                    } else {
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                                            dragY = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            impactMed.prepare(); impactHeavy.prepare(); selection.prepare()
            withAnimation(.easeOut(duration: 0.55).delay(0.08)) { appeared = true }
        }
    }

    // MARK: - Place trigger

    private func triggerPlace(dbRestY: CGFloat, travelDist: CGFloat) {
        impactHeavy.impactOccurred()
        // Spring the dumbbell to scan frame center
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            placed = true
        }
        // Reveal content shortly after
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            withAnimation(.easeOut(duration: 0.55)) {
                contentVisible = true
            }
        }
    }

    // MARK: - Scan Frame

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

// MARK: - Swipe hint (Apple lock-screen style)

private struct SwipeHintView: View {
    @State private var bounce: CGFloat = 0
    @State private var opacity: Double = 1

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
            // Pulse the whole hint subtly
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) {
                opacity = 0.45
            }
        }
    }
}

// MARK: - Sweep line (adapts to dark/light)

private struct SplashSweepLine: View {
    @State private var progress: CGFloat = 0
    @State private var opacity:  Double  = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, Color.primary.opacity(0.45), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .offset(y: progress * geo.size.height)
                .opacity(opacity)
        }
        .onAppear { animate() }
    }

    private func animate() {
        progress = 0; opacity = 0
        withAnimation(.easeIn(duration: 0.18))          { opacity   = 0.9 }
        withAnimation(.easeInOut(duration: 2.8))        { progress  = 1   }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.25))     { opacity   = 0   }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { animate() }
        }
    }
}
