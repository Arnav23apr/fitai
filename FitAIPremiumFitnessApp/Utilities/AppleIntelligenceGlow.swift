import SwiftUI
import Combine

struct AppleIntelligenceGlowBorder: View {
    let frame: CGRect
    let cornerRadius: CGFloat

    @State private var gradientStops: [Gradient.Stop] = AppleIntelligenceGlowBorder.randomStops()

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        let glowSpread: CGFloat = 28

        Canvas { context, size in
            context.addFilter(.blur(radius: 0))
        }
        .frame(width: 0, height: 0)
        .hidden()

        ZStack {
            outerGlow(spread: glowSpread, lineWidth: 24, blur: 22)
            outerGlow(spread: glowSpread, lineWidth: 14, blur: 10)
            outerGlow(spread: glowSpread, lineWidth: 6, blur: 4)
            outerGlow(spread: glowSpread, lineWidth: 2.5, blur: 0)
        }
        .mask {
            Rectangle()
                .fill(.white)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                gradientStops = Self.randomStops()
            }
        }
        .allowsHitTesting(false)
    }

    private func outerGlow(spread: CGFloat, lineWidth: CGFloat, blur: CGFloat) -> some View {
        let expandedWidth = frame.width + spread
        let expandedHeight = frame.height + spread

        return RoundedRectangle(cornerRadius: cornerRadius + spread / 2)
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: gradientStops),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: expandedWidth, height: expandedHeight)
            .position(x: frame.midX, y: frame.midY)
            .blur(radius: blur)
    }

    static func randomStops() -> [Gradient.Stop] {
        [
            Gradient.Stop(color: Color(red: 0.737, green: 0.510, blue: 0.953), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 0.961, green: 0.726, blue: 0.918), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 0.553, green: 0.624, blue: 1.0), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 1.0, green: 0.404, blue: 0.471), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 1.0, green: 0.729, blue: 0.443), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 0.776, green: 0.525, blue: 1.0), location: Double.random(in: 0...1)),
        ].sorted { $0.location < $1.location }
    }
}
