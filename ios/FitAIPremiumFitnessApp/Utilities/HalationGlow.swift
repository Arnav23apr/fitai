import SwiftUI

/// Subtle Siri/Apple-Intelligence-style chromatic-rim bloom. Splits
/// the layer's RGB channels and offsets each outward by ~1pt, then
/// bleeds a 5-tap blur on the alpha so the edges read as a halated
/// glow rather than a sharp outline.
///
/// Use the `.halationGlow(intensity:)` modifier on any view. Pair
/// with a slow breathing animation (2s loop) for the ambient hero
/// version, or punch intensity up briefly for a completion
/// celebration moment.
struct HalationGlowModifier: ViewModifier {
    /// 0 = no effect; 1 = subtle Apple-tasteful baseline; 1.5+ punches
    /// into "Siri WWDC26 teaser" territory.
    var intensity: Double = 1.0

    /// Read via a background GeometryReader instead of wrapping the
    /// whole modifier in one — a top-level GeometryReader expands to
    /// fill the parent and would shove the host view to top-leading.
    /// Storing the size in state and letting the layerEffect re-fire
    /// on size change keeps the host's natural layout intact.
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { size = geo.size }
                        .onChange(of: geo.size) { _, new in size = new }
                }
            )
            .layerEffect(
                ShaderLibrary.halation(
                    .float2(Float(size.width), Float(size.height)),
                    .float(Float(intensity))
                ),
                maxSampleOffset: CGSize(width: 6, height: 6),
                isEnabled: intensity > 0.05 && size != .zero
            )
    }
}

extension View {
    /// Wrap the receiver in a halation chromatic-rim glow.
    /// `intensity` is animatable — drive it from a `@State` Double to
    /// breathe the rim or punch it during completion moments.
    func halationGlow(intensity: Double = 1.0) -> some View {
        modifier(HalationGlowModifier(intensity: intensity))
    }
}
