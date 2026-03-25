import SwiftUI

struct SwipeUpSplashView: View {
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var appeared:       Bool    = false
    @State private var dragY:          CGFloat = 0
    @State private var isDragging:     Bool    = false
    @State private var placed:         Bool    = false
    @State private var contentVisible: Bool    = false
    @State private var nearThreshold:  Bool    = false   // for escalating haptics

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
            let safeTop    = geo.safeAreaInsets.top

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

                // ── Z4: FitAI wordmark ────────────────────────────────────────
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

                // ── Z5: Get Started button ────────────────────────────────────
                VStack {
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, safeBottom + 20)
                }
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
            // Re-read progress inside onChange so the escalation check has fresh value
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
    }

    // MARK: - Snap to frame

    private func triggerPlace() {
        // Satisfying "locked in" haptic — heavy + success notification back to back
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

// MARK: - Sweep line

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
        withAnimation(.easeIn(duration: 0.18))   { opacity  = 0.9 }
        withAnimation(.easeInOut(duration: 2.8)) { progress = 1   }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.25)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { animate() }
        }
    }
}
