#include <metal_stdlib>
using namespace metal;

// Drifting embers overlay used by LossAversionView. Slow-rising red/orange
// particles — visual reinforcement of the "time is running out" theme.
//
// Used via SwiftUI's `.fill(ShaderLibrary.lossEmbers(...))` on a Rectangle.
// Position is in user-space points, not pixels.

// Cheap hash for stable per-particle seeds. Inigo Quilez style.
static float embHash(float2 p) {
    p = fract(p * float2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

// Single-particle contribution. Returns RGB (already tinted) and intensity
// in `out_alpha` so the caller can composite against transparent.
static half3 emberAt(float2 position, int i, float time, float2 size, thread float &out_alpha) {
    float pi = float(i);

    // Stable per-particle seeds.
    float seedX = embHash(float2(pi, 7.13));
    float seedY = embHash(float2(pi, 11.71));
    float seedR = embHash(float2(pi, 17.31));
    float seedF = embHash(float2(pi, 23.91));

    // Slight horizontal sway so particles don't move in straight lines.
    float driftX = sin(time * 0.4 + pi * 1.3) * 22.0;

    // Particle position. Y rises continuously; we wrap modulo
    // (size.y * 1.3) so particles re-enter from the bottom edge a bit
    // off-screen and fade in naturally.
    float speed = 18.0 + seedR * 14.0;
    float px = seedX * size.x + driftX;
    float py = fmod(seedY * size.y + size.y * 0.3 - time * speed, size.y * 1.3) - size.y * 0.15;

    // Particle radius and core glow.
    float radius = 1.8 + seedR * 3.2;
    float dist = distance(position, float2(px, py));
    float core = exp(-dist * dist / (radius * radius * 1.4));

    // Flicker — each particle has its own phase.
    float flicker = 0.55 + 0.45 * sin(time * 1.6 + seedF * 6.28);

    // Fade in/out near the top so particles don't pop when wrapping.
    float fadeY = smoothstep(0.0, size.y * 0.15, py) *
                  (1.0 - smoothstep(size.y * 0.85, size.y * 1.05, py));

    float intensity = core * flicker * fadeY * 0.55;

    // Red-orange ember tint. Slight per-particle hue jitter for variety.
    float hueJitter = (seedR - 0.5) * 0.15;
    half3 tint = half3(1.0, 0.42 + hueJitter, 0.18);

    out_alpha = intensity;
    return tint * half(intensity);
}

[[ stitchable ]] half4 lossEmbers(float2 position, float time, float2 size) {
    half3 accum = half3(0.0);
    float totalAlpha = 0.0;

    // 14 particles is the visual sweet spot — enough density to feel
    // alive, cheap enough to render at 30fps on older devices.
    const int particleCount = 14;
    for (int i = 0; i < particleCount; i++) {
        float a = 0.0;
        accum += emberAt(position, i, time, size, a);
        totalAlpha += a;
    }

    // Composite. Cap alpha so a chance pile-up of two particles in the
    // same pixel doesn't blow out the layer.
    float alpha = min(totalAlpha, 1.0);
    return half4(accum, half(alpha));
}
