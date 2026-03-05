import SwiftUI

struct AppleIntelligenceGlowBorder: View {
    let frame: CGRect
    let cornerRadius: CGFloat
    var glowSpread: CGFloat = 28

    @State private var gradientStops: [Gradient.Stop] = AppleIntelligenceGlowBorder.randomStops()

    var body: some View {
        let cr = cornerRadius + glowSpread / 2

        ZStack {
            glowLayer(lineWidth: 15, blur: 15, cornerRadius: cr)
            glowLayer(lineWidth: 11, blur: 12, cornerRadius: cr)
            glowLayer(lineWidth: 9, blur: 4, cornerRadius: cr)
            glowLayer(lineWidth: 6, blur: 0, cornerRadius: cr)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    gradientStops = Self.randomStops()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func glowLayer(lineWidth: CGFloat, blur: CGFloat, cornerRadius: CGFloat) -> some View {
        let w = frame.width + glowSpread
        let h = frame.height + glowSpread

        return RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: gradientStops),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: w, height: h)
            .position(x: frame.midX, y: frame.midY)
            .blur(radius: blur)
    }

    static func randomStops() -> [Gradient.Stop] {
        [
            Gradient.Stop(color: Color(red: 188/255, green: 130/255, blue: 243/255), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 245/255, green: 185/255, blue: 234/255), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 141/255, green: 159/255, blue: 255/255), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 255/255, green: 103/255, blue: 120/255), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 255/255, green: 186/255, blue: 113/255), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(red: 198/255, green: 134/255, blue: 255/255), location: Double.random(in: 0...1)),
        ].sorted { $0.location < $1.location }
    }
}
