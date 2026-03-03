import SwiftUI
import Combine

struct AppleIntelligenceGlowBorder: View {
    let frame: CGRect
    let cornerRadius: CGFloat

    @State private var gradientStops: [Gradient.Stop] = AppleIntelligenceGlowBorder.randomStops()

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        let inset: CGFloat = -6
        let expandedFrame = frame.insetBy(dx: inset, dy: inset)

        ZStack {
            glowLayer(expandedFrame: expandedFrame, lineWidth: 15, blur: 15)
            glowLayer(expandedFrame: expandedFrame, lineWidth: 11, blur: 12)
            glowLayer(expandedFrame: expandedFrame, lineWidth: 9, blur: 4)
            sharpLayer(expandedFrame: expandedFrame, lineWidth: 3)
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                gradientStops = Self.randomStops()
            }
        }
        .allowsHitTesting(false)
    }

    private func glowLayer(expandedFrame: CGRect, lineWidth: CGFloat, blur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius + 4)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: gradientStops),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: expandedFrame.width, height: expandedFrame.height)
            .position(x: expandedFrame.midX, y: expandedFrame.midY)
            .blur(radius: blur)
    }

    private func sharpLayer(expandedFrame: CGRect, lineWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius + 4)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: gradientStops),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: expandedFrame.width, height: expandedFrame.height)
            .position(x: expandedFrame.midX, y: expandedFrame.midY)
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
