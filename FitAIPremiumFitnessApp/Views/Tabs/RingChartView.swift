import SwiftUI

struct RingChartView: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: [Color]
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: gradient + [gradient.first ?? .blue],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if animatedProgress > 0.02 {
                Circle()
                    .fill(gradient.last ?? .blue)
                    .frame(width: lineWidth, height: lineWidth)
                    .shadow(color: (gradient.last ?? .blue).opacity(0.6), radius: 4)
                    .offset(y: -size / 2)
                    .rotationEffect(.degrees(animatedProgress * 360))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = min(newValue, 1.0)
            }
        }
    }
}

struct TripleRingView: View {
    let moveProgress: Double
    let trainProgress: Double
    let competeProgress: Double

    var body: some View {
        ZStack {
            RingChartView(
                progress: competeProgress,
                lineWidth: 10,
                gradient: [.orange, .red],
                size: 100
            )

            RingChartView(
                progress: trainProgress,
                lineWidth: 10,
                gradient: [.green, .mint],
                size: 74
            )

            RingChartView(
                progress: moveProgress,
                lineWidth: 10,
                gradient: [.cyan, .blue],
                size: 48
            )
        }
    }
}
