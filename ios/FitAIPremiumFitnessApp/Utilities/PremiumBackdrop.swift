import SwiftUI

/// Reusable premium backdrop. Wraps the `premiumBackdrop` Metal shader
/// (a stitchable port of WelcomeView's `bg_frag`) so any screen can
/// place its content over the exact same canvas the welcome hero sits
/// on: near-black base, breathing top spotlight, FBM noise, vignette,
/// film grain.
///
/// Drop in as the first child of a `ZStack`. The backdrop ignores the
/// safe area so it bleeds to the edges; content above it lays out
/// normally.
///
/// Pairs with `MetalEmbersOverlay` for screens that want rising-ember
/// energy, and with the existing `DumbbellSceneView` for screens that
/// want the chrome dumbbell hero.
struct PremiumBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = Float(ctx.date.timeIntervalSinceReferenceDate)
                let w = Float(geo.size.width)
                let h = Float(geo.size.height)

                Rectangle()
                    .fill(
                        ShaderLibrary.premiumBackdrop(
                            .float(t),
                            .float2(w, h)
                        )
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
