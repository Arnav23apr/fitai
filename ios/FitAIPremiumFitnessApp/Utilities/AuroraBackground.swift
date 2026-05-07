import SwiftUI

/// Subtle drifting mesh gradient — Apple-Intelligence-style soft aurora.
/// Used as a background on premium onboarding/info screens to add depth
/// without competing with content. Native `MeshGradient` (iOS 18+)
/// animated by `TimelineView` at 30fps, so it's GPU-cheap and pauses
/// when the view is offscreen.
///
/// Pass colors in any order — they cycle slowly through the 9 mesh
/// control points. Keep alpha low (0.04–0.10) for the subtle "barely
/// there" feel; higher values get loud fast.
struct AuroraBackground: View {
    let colors: [Color]
    var speed: Double = 0.12
    var saturation: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * speed

            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints(t: t),
                colors: meshColors(t: t),
                smoothsColors: true
            )
            .saturation(saturation)
            .ignoresSafeArea()
        }
    }

    /// 3×3 grid where the inner rows drift on slow sine curves.
    /// Corners stay anchored so the gradient doesn't feel like it's swimming.
    private func meshPoints(t: Double) -> [SIMD2<Float>] {
        let d1 = Float(sin(t * 0.7)) * 0.10
        let d2 = Float(cos(t * 0.5)) * 0.10
        let d3 = Float(sin(t * 0.9 + 1.5)) * 0.12
        let d4 = Float(cos(t * 0.6 + 2.1)) * 0.10
        let d5 = Float(sin(t * 0.4 + 3.7)) * 0.08

        return [
            SIMD2(0.0,         0.0),
            SIMD2(0.5 + d1,    0.0),
            SIMD2(1.0,         0.0),
            SIMD2(0.0,         0.5 + d2),
            SIMD2(0.5 + d3,    0.5 + d4),
            SIMD2(1.0,         0.5 - d2),
            SIMD2(0.0,         1.0),
            SIMD2(0.5 - d5,    1.0),
            SIMD2(1.0,         1.0),
        ]
    }

    /// Cycle through the provided colors so each control point drifts
    /// through the palette over time. Slow rotation = subtle hue shift.
    private func meshColors(t: Double) -> [Color] {
        guard !colors.isEmpty else { return Array(repeating: .clear, count: 9) }
        let n = colors.count
        return (0..<9).map { i in
            let phase = (t * 0.18) + Double(i) * 0.55
            let idx = (Int(phase) + i) % n
            return colors[idx]
        }
    }
}
