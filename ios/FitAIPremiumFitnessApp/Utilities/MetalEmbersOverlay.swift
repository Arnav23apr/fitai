import SwiftUI

/// Metal-rendered drifting embers overlay. Slow red/orange particles
/// rising upward — visual reinforcement of "time is running out" on the
/// loss-aversion screen. Sits above `AuroraBackground` and below content.
///
/// Implementation: TimelineView drives a `time` uniform into a stitchable
/// Metal shader (`lossEmbers` in `Metal/LossAversionShader.metal`). The
/// shader returns transparent + ember-colored pixels, so it composites
/// cleanly over whatever's underneath without needing a blend mode.
///
/// Performance: 14 particles × 30fps. GPU-cheap. Pauses automatically when
/// the parent view goes offscreen because TimelineView is suspended.
struct MetalEmbersOverlay: View {
    /// Adds a subtle plus-lighter blend so the embers brighten the
    /// AuroraBackground gradient underneath instead of just sitting on
    /// top. Set to false if you want them to read as opaque dots.
    var brighten: Bool = true

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = Float(ctx.date.timeIntervalSinceReferenceDate)
                let w = Float(geo.size.width)
                let h = Float(geo.size.height)

                Rectangle()
                    .fill(
                        ShaderLibrary.lossEmbers(
                            .float(t),
                            .float2(w, h)
                        )
                    )
                    .blendMode(brighten ? .plusLighter : .normal)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
