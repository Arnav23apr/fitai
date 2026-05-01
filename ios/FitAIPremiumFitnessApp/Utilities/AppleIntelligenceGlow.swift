import SwiftUI

struct AppleIntelligenceGlowBorder: View {
    let frame: CGRect
    let cornerRadius: CGFloat
    var glowSpread: CGFloat = 28
    var useCapsule: Bool = false

    @State private var rotation: Double = 0

    private let colors: [Color] = [
        Color(red: 0.55, green: 0.36, blue: 1.0),   // purple
        Color(red: 0.55, green: 0.62, blue: 1.0),   // blue-purple
        Color(red: 0.96, green: 0.40, blue: 0.47),   // coral
        Color(red: 1.00, green: 0.73, blue: 0.44),   // warm orange
        Color(red: 0.96, green: 0.73, blue: 0.92),   // pink
        Color(red: 0.55, green: 0.36, blue: 1.0),    // purple (wrap)
    ]

    var body: some View {
        ZStack {
            glowLayer(lineWidth: 18, blur: 20, opacity: 0.5)
            glowLayer(lineWidth: 12, blur: 10, opacity: 0.7)
            glowLayer(lineWidth: 5, blur: 3, opacity: 0.9)
            glowLayer(lineWidth: 2.5, blur: 0, opacity: 1.0)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .allowsHitTesting(false)
    }

    private func glowLayer(lineWidth: CGFloat, blur: CGFloat, opacity: Double) -> some View {
        let w = frame.width + glowSpread
        let h = frame.height + glowSpread
        let gradient = AngularGradient(
            colors: colors,
            center: .center,
            angle: .degrees(rotation)
        )

        return Group {
            if useCapsule {
                Capsule()
                    .strokeBorder(gradient, lineWidth: lineWidth)
                    .frame(width: w, height: h)
            } else {
                let cr = cornerRadius + glowSpread / 2
                RoundedRectangle(cornerRadius: cr)
                    .strokeBorder(gradient, lineWidth: lineWidth)
                    .frame(width: w, height: h)
            }
        }
        .position(x: frame.midX, y: frame.midY)
        .blur(radius: blur)
        .opacity(opacity)
    }
}
