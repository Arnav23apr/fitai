#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Halation glow — Siri/Apple-Intelligence-style chromatic-aberration
// bloom. Splits the source layer into R/G/B channels, offsets each
// outward by a small radial amount, then averages a 5-tap soft blur so
// bright edges bleed into surrounding pixels. The result is a subtle
// chromatic rim around the layer, exactly the "premium AI" glow the
// research flagged as the current Apple visual signature.
//
// Tuned for the "subtle" variant: 1.0pt channel offset, ~3pt blur
// reach. Loud variants pass a higher `intensity`.

[[ stitchable ]] half4 halation(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float intensity
) {
    half4 base = layer.sample(position);

    // Radial direction from the layer center — used to split the
    // chromatic channels outward, so the rim color depends on
    // direction (cooler at top, warmer at bottom is a common
    // Apple/Siri look, but for cohesion we keep it neutral here).
    float2 center = size * 0.5;
    float2 dir = position - center;
    float len = max(length(dir), 0.0001);
    float2 unit = dir / len;

    // Channel offsets. Cheap and effective: read R slightly inward,
    // B slightly outward, G centered. Scaled by intensity so callers
    // can dial the look up at completion moments.
    float offset = 1.0 * intensity;
    float2 rPos = position - unit * offset;
    float2 bPos = position + unit * offset;

    half r = layer.sample(rPos).r;
    half g = base.g;
    half b = layer.sample(bPos).b;

    // 5-tap soft blur on the alpha channel so the rim halos rather
    // than hard-edges. Plus-shaped sample pattern; cheap on mobile GPU.
    float spread = 3.0 * intensity;
    half a0 = layer.sample(position).a;
    half a1 = layer.sample(position + float2( spread, 0)).a;
    half a2 = layer.sample(position + float2(-spread, 0)).a;
    half a3 = layer.sample(position + float2(0,  spread)).a;
    half a4 = layer.sample(position + float2(0, -spread)).a;
    half bloomA = (a0 + a1 + a2 + a3 + a4) * 0.2;

    // Composite: take the original alpha but boost edges with the
    // bloom contribution, weighted by intensity.
    half a = max(base.a, bloomA * half(0.85 * intensity));

    return half4(r, g, b, a);
}
