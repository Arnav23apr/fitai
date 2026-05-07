import SwiftUI

nonisolated enum AnalyzingMode {
    case scan
    case battle
}

/// AI-analyzing overlay shown during scan + battle photo analysis.
///
/// Apple Intelligence-style: solid black canvas with an iridescent
/// angular-gradient border that flows continuously around the screen.
/// All the AI motion lives on the perimeter so the centered dumbbell
/// + shimmering phrase never have to compete with it.
///
/// Three layers:
///   1. Pure black background (covers tab bar — presented as fullScreenCover)
///   2. Iridescent border looping around the screen edge
///   3. Centered DumbbellSceneView hero + shimmer text below
struct AnalyzingOverlayView: View {
    let mode: AnalyzingMode

    init(mode: AnalyzingMode = .scan) {
        self.mode = mode
    }

    @State private var currentIndex: Int = 0
    @State private var dumbbellSettled: Bool = false
    @State private var glowPulse: CGFloat = 0.85
    @State private var hapticTick: Int = 0
    @State private var phraseTask: Task<Void, Never>? = nil

    private static let scanPhrases: [AnalyzingPhrase] = [
        AnalyzingPhrase(text: "Be honest… did you skip legs?", icon: "figure.walk"),
        AnalyzingPhrase(text: "Natty or not…?", icon: "syringe.fill"),
        AnalyzingPhrase(text: "Consulting the aesthetic council", icon: "person.3.fill"),
        AnalyzingPhrase(text: "Detecting possible sleeper build", icon: "eye.fill"),
        AnalyzingPhrase(text: "Checking for chicken legs", icon: "bird.fill"),
        AnalyzingPhrase(text: "Rating the gains", icon: "star.fill"),
        AnalyzingPhrase(text: "V taper?", icon: "triangle.fill"),
        AnalyzingPhrase(text: "Counting abs... if any", icon: "rectangle.split.3x3"),
        AnalyzingPhrase(text: "Boulder shoulders?", icon: "circle.fill"),
        AnalyzingPhrase(text: "Mog potential loading", icon: "bolt.fill"),
    ]

    private static let battlePhrases: [AnalyzingPhrase] = [
        AnalyzingPhrase(text: "Running side-by-side mog analysis", icon: "person.2.fill"),
        AnalyzingPhrase(text: "Calculating aura differential", icon: "sparkles"),
        AnalyzingPhrase(text: "Checking who skipped legs first", icon: "figure.walk"),
        AnalyzingPhrase(text: "Comparing dominance levels", icon: "bolt.fill"),
        AnalyzingPhrase(text: "Evaluating genetic lottery odds", icon: "dice.fill"),
        AnalyzingPhrase(text: "Measuring mog distance", icon: "ruler.fill"),
        AnalyzingPhrase(text: "Analyzing power levels", icon: "flame.fill"),
        AnalyzingPhrase(text: "Judging the physique showdown", icon: "trophy.fill"),
    ]

    private var phrases: [AnalyzingPhrase] {
        switch mode {
        case .scan:   return Self.scanPhrases
        case .battle: return Self.battlePhrases
        }
    }

    private var currentPhrase: AnalyzingPhrase {
        phrases[currentIndex % phrases.count]
    }

    var body: some View {
        ZStack {
            // Layer 1 — solid black canvas
            Color.black
                .ignoresSafeArea()

            // Layer 2 — centered hero + text
            VStack(spacing: 36) {
                Spacer()
                dumbbellHero
                phraseText
                    .padding(.horizontal, 36)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        // Tactile click on every phrase morph — `.selection` reads cleanly
        // for text-change events (same haptic style iOS uses for the
        // picker wheel and segmented control taps). Stronger than the
        // earlier light-impact tick so it actually registers in pocket.
        .sensoryFeedback(.selection, trigger: hapticTick)
        .onAppear { startAnimations() }
        .onDisappear { phraseTask?.cancel() }
    }

    // MARK: - Dumbbell hero (PlanPreview-pattern)

    private var dumbbellHero: some View {
        ZStack {
            // Soft pulsing radial halo — pure white at low opacity reads
            // clean on the black bg without competing with the border.
            RadialGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 130
            )
            .frame(width: 260, height: 260)
            .scaleEffect(glowPulse)

            DumbbellSceneView(transparent: true, darkChrome: false)
                .frame(width: 220, height: 220)
                .shadow(color: .white.opacity(0.10), radius: 20, y: 6)
                .rotationEffect(.degrees(dumbbellSettled ? 0 : -90))
                .scaleEffect(dumbbellSettled ? 1 : 0.85)
                .opacity(dumbbellSettled ? 1 : 0)
                .allowsHitTesting(false)
        }
        .frame(width: 260, height: 260)
    }

    // MARK: - Rotating phrase text
    // Uses `.contentTransition(.numericText())` — the same character-level
    // morphing animation as the "Your plan is ready" headline in
    // PlanPreviewView. Each character slides/morphs into the next phrase
    // instead of the whole text fading. No view-identity change (no .id()),
    // so SwiftUI can diff the characters and animate the deltas.
    private var phraseText: some View {
        Text(currentPhrase.text)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .contentTransition(.numericText())
    }

    // MARK: - Choreography

    private func startAnimations() {
        // Dumbbell entry — rotate from -90° + scale up via spring.
        withAnimation(.spring(duration: 1.0, bounce: 0.25)) {
            dumbbellSettled = true
        }
        // Breathing glow loop on the dumbbell halo.
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = 1.15
        }
        // Phrase rotation every 1.5s — task-driven so we can cancel cleanly.
        phraseTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                if Task.isCancelled { return }
                // Slightly longer curve than a typical fade so the
                // numericText character morphs are clearly visible.
                withAnimation(.easeInOut(duration: 0.55)) {
                    currentIndex = (currentIndex + 1) % phrases.count
                }
                hapticTick &+= 1
            }
        }
    }
}

private struct AnalyzingPhrase {
    let text: String
    let icon: String
}
