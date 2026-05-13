#include <metal_stdlib>
using namespace metal;

// Premium backdrop — stitchable port of bg_frag from WelcomeShader.metal so
// SwiftUI views can compose it via `.fill(ShaderLibrary.premiumBackdrop(...))`
// without needing an MTKView host. Same near-black base, breathing top
// spotlight, FBM noise, bottom edge glow, vignette, and film grain that the
// welcome scene uses, so any screen wrapping a `PremiumBackdrop` reads as
// the same canvas the dumbbell hero sits on.

// MARK: - Noise helpers (same algorithm as WelcomeShader.metal)

static float bdHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float bdNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = bdHash(i);
    float b = bdHash(i + float2(1, 0));
    float c = bdHash(i + float2(0, 1));
    float d = bdHash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float bdFbm(float2 p) {
    float v = 0.0, a = 0.5;
    float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        v += a * bdNoise(p);
        p  = rot * p * 2.1;
        a *= 0.5;
    }
    return v;
}

// MARK: - Stitchable entry

[[ stitchable ]] half4 premiumBackdrop(float2 position, float time, float2 size) {
    float2 uv  = position / size;
    float2 uvC = uv - 0.5;
    float t    = time;

    // Near-black premium base — must match Color(red: 0.028, green: 0.028,
    // blue: 0.034) on the SwiftUI side so the welcome screen and the
    // backdrop-using screens share the exact same base layer.
    float3 col = float3(0.028, 0.028, 0.034);

    // Subtle animated FBM micro-detail. Very low contribution; just enough
    // to keep the surface from reading as a flat color.
    float n = bdFbm(uv * 3.5 + float2(t * 0.015, t * 0.010));
    col += float3(0.004, 0.003, 0.006) * n;

    // Soft top-center spotlight where the hero element typically sits.
    // Breathes slowly so the scene feels alive without anything moving.
    float2 spotUV = uv - float2(0.5, 0.27);
    float spot = exp(-dot(spotUV * float2(1.0, 1.2), spotUV * float2(1.0, 1.2)) * 7.0);
    float breathe = 0.82 + 0.18 * sin(t * 0.38);
    col += float3(0.055, 0.060, 0.080) * spot * breathe;

    // Bottom edge glow grounds the screen and gives the CTA pill a
    // visual floor it sits on top of.
    float bottomEdge = exp(-(1.0 - uv.y) * 10.0);
    col += float3(0.014, 0.014, 0.022) * bottomEdge;

    // Strong vignette: corner-darkening so the eye is funneled to center.
    float vign = 1.0 - smoothstep(0.18, 0.82, length(uvC * float2(1.0, 1.45)));
    col *= vign * vign;

    // Film grain — premium-grade texture. The hash-based variant we use
    // here is deterministic per (position, time) so it animates without
    // looking like static.
    float grain = fract(sin(dot(position + t * 17.3, float2(12.9898, 78.233))) * 43758.5);
    col += (grain - 0.5) * 0.016;

    return half4(half3(saturate(col)), 1.0);
}
