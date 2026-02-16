import SwiftUI

nonisolated enum AnalyzingMode {
    case scan
    case battle
}

struct AnalyzingOverlayView: View {
    let mode: AnalyzingMode

    init(mode: AnalyzingMode = .scan) {
        self.mode = mode
    }

    @State private var currentIndex: Int = 0
    @State private var textOpacity: Double = 1.0
    @State private var textOffset: Double = 0
    @State private var dotCount: Int = 0
    @State private var pulseScale: Double = 1.0
    @State private var iconRotation: Double = 0

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
        case .scan: return Self.scanPhrases
        case .battle: return Self.battlePhrases
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                Image(systemName: phrases[currentIndex].icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.9))
                    .rotationEffect(.degrees(iconRotation))
                    .opacity(textOpacity)
                    .scaleEffect(textOpacity)
            }

            VStack(spacing: 10) {
                Text(phrases[currentIndex].text + String(repeating: ".", count: dotCount))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                    .animation(.easeInOut(duration: 0.3), value: dotCount)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .scaleEffect(dotCount > i ? 1.3 : 0.7)
                            .opacity(dotCount > i ? 1 : 0.3)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(Double(i) * 0.05), value: dotCount)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.92))
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        cycleDots()
        cyclePhrase()
    }

    private func cycleDots() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                dotCount = (dotCount % 3) + 1
                if dotCount == 1 {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        }
    }

    private func cyclePhrase() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))

                withAnimation(.easeIn(duration: 0.25)) {
                    textOpacity = 0
                    textOffset = -10
                }

                try? await Task.sleep(for: .milliseconds(300))

                currentIndex = (currentIndex + 1) % phrases.count
                dotCount = 0
                textOffset = 10

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    textOpacity = 1
                    textOffset = 0
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    iconRotation += 360
                }
            }
        }
    }
}

private struct AnalyzingPhrase {
    let text: String
    let icon: String
}
