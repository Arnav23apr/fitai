import SwiftUI

/// Wabi-inspired swipe-up splash:
/// White screen → FitAI wordmark at top → liquid glass bubble at bottom containing the 3D dumbbell.
/// User drags the bubble upward; at threshold it snaps to the top and triggers onFinished.
struct SwipeUpSplashView: View {
    var onFinished: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var launched: Bool = false
    @State private var logoOpacity: Double = 0
    @State private var bubbleOpacity: Double = 0
    @State private var completed: Bool = false

    private let impactMed   = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection   = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            let screenH = geo.size.height
            // Bubble resting Y (distance from bottom of screen)
            let restingBottomPad: CGFloat = 64
            // How far from bottom the bubble center sits at rest
            let bubbleSize: CGFloat = 180
            let restingY = screenH - restingBottomPad - bubbleSize / 2

            ZStack {
                // White background
                Color.white.ignoresSafeArea()

                // FitAI wordmark — top area
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(white: 0.1))
                        Text("FitAI")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Color(white: 0.1))
                            .tracking(-0.5)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 28)

                    Spacer()
                }
                .opacity(logoOpacity)

                // Hint label
                if !completed {
                    VStack {
                        Spacer()
                        Text("Swipe up to start")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.bottom, restingBottomPad + bubbleSize + 20)
                    }
                    .opacity(bubbleOpacity * Double(1 - abs(dragOffset) / (screenH * 0.3)))
                    .animation(.easeOut(duration: 0.2), value: dragOffset)
                }

                // Liquid glass bubble with dumbbell inside
                bubbleView(geo: geo)
                    .position(x: geo.size.width / 2,
                              y: restingY + dragOffset)
                    .opacity(bubbleOpacity)
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                guard !completed else { return }
                                let dy = min(0, value.translation.height) // only allow upward
                                if !isDragging {
                                    isDragging = true
                                    impactMed.impactOccurred()
                                }
                                dragOffset = dy
                                // Subtle selection tick every 40pt
                                if Int(abs(dy)) % 40 < 4 && abs(dy) > 20 {
                                    selection.selectionChanged()
                                }
                            }
                            .onEnded { value in
                                guard !completed else { return }
                                isDragging = false
                                let velocity = value.predictedEndTranslation.height
                                let threshold = screenH * 0.32

                                if dragOffset < -threshold || velocity < -600 {
                                    // Launch!
                                    triggerLaunch(screenH: screenH)
                                } else {
                                    // Snap back
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .onAppear {
            impactMed.prepare(); impactHeavy.prepare(); selection.prepare()
            withAnimation(.easeOut(duration: 0.55)) {
                logoOpacity = 1
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.3)) {
                bubbleOpacity = 1
            }
        }
    }

    // MARK: - Bubble

    private func bubbleView(geo: GeometryProxy) -> some View {
        let bubbleSize: CGFloat = 180
        // Scale down slightly as it's dragged up (feels like it's shrinking into distance)
        let progress = min(abs(dragOffset) / (geo.size.height * 0.5), 1.0)
        let scale = 1.0 - progress * 0.12

        return ZStack {
            // Liquid glass capsule/circle
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 24, y: 8)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)

            // 3D dumbbell scene inside the bubble
            DumbbellSceneView()
                .clipShape(Circle())
                .allowsHitTesting(false)

            // Grab handle at the bottom of bubble
            VStack {
                Spacer()
                Capsule()
                    .fill(Color(white: 0.55).opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: bubbleSize, height: bubbleSize)
        .scaleEffect(scale)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.78), value: dragOffset)
    }

    // MARK: - Launch

    private func triggerLaunch(screenH: CGFloat) {
        completed = true
        impactHeavy.impactOccurred()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            dragOffset = -screenH
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            logoOpacity = 0
            bubbleOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onFinished()
        }
    }
}
