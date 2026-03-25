#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Uniforms (must match Swift struct WelcomeMTLUniforms)

struct Uniforms {
    float  time;
    float2 resolution;
};

// MARK: - Noise Helpers

static float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1, 0));
    float c = hash(i + float2(0, 1));
    float d = hash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p  = rot * p * 2.1;
        a *= 0.5;
    }
    return v;
}

// MARK: - Background Pipeline

struct BGInOut {
    float4 position [[position]];
};

// Full-screen triangle (3 vertices, no buffer needed)
vertex BGInOut bg_vert(uint vid [[vertex_id]]) {
    BGInOut out;
    float2 pos;
    pos.x = (vid == 2) ?  3.0 : -1.0;
    pos.y = (vid == 0) ? -3.0 :  1.0;
    out.position = float4(pos, 0, 1);
    return out;
}

fragment float4 bg_frag(BGInOut in [[stage_in]],
                         constant Uniforms& u [[buffer(0)]]) {
    float2 uv  = in.position.xy / u.resolution;
    uv.y       = 1.0 - uv.y;
    float2 uvC = uv - 0.5;
    float t    = u.time;

    // --- Near-black premium base ---
    float3 col = float3(0.028, 0.028, 0.034);

    // --- Subtle animated noise texture (micro-detail only) ---
    float n = fbm(uv * 3.5 + float2(t * 0.015, t * 0.010));
    col += float3(0.004, 0.003, 0.006) * n;

    // --- Soft spotlight at top-center, where dumbbell sits ---
    float2 spotUV = uv - float2(0.5, 0.27);
    float spot = exp(-dot(spotUV * float2(1.0, 1.2), spotUV * float2(1.0, 1.2)) * 7.0);
    float breathe = 0.82 + 0.18 * sin(t * 0.38);
    col += float3(0.055, 0.060, 0.080) * spot * breathe;

    // --- Very faint bottom edge glow (grounds the scene) ---
    float bottomEdge = exp(-(1.0 - uv.y) * 10.0);
    col += float3(0.014, 0.014, 0.022) * bottomEdge;

    // --- Strong vignette: darkens corners/edges ---
    float vign = 1.0 - smoothstep(0.18, 0.82, length(uvC * float2(1.0, 1.45)));
    col *= vign * vign;

    // --- Film grain for premium texture ---
    float grain = fract(sin(dot(in.position.xy + t * 17.3, float2(12.9898, 78.233))) * 43758.5);
    col += (grain - 0.5) * 0.016;

    return float4(saturate(col), 1.0);
}

// MARK: - Particle Pipeline
// Each particle is float4(normX, normY, phase, size)

struct ParticleOut {
    float4 position  [[position]];
    float  pointSize [[point_size]];
    float  alpha;
    float3 color;
};

vertex ParticleOut particle_vert(uint               vid       [[vertex_id]],
                                  constant float4*   particles [[buffer(0)]],
                                  constant Uniforms& u         [[buffer(1)]]) {
    float4 p  = particles[vid];
    float  px = p.x;
    float  py = p.y + sin(u.time * 0.40 + p.z) * 0.022;

    // Silver-white color with very subtle cool tint variation
    float shimmer = 0.5 + 0.5 * sin(p.z * 1.8 + u.time * 0.25);
    float3 col = float3(0.68 + 0.10 * shimmer,
                        0.72 + 0.08 * shimmer,
                        0.88 + 0.10 * shimmer);

    // Low, gentle pulsing alpha
    float alpha = (sin(u.time * 0.55 + p.z) + 1.0) * 0.5 * 0.20 + 0.02;

    ParticleOut out;
    out.position  = float4(px * 2.0 - 1.0, -(py * 2.0 - 1.0), 0, 1);
    out.pointSize = p.w * u.resolution.y * 0.0055;  // smaller
    out.alpha     = alpha;
    out.color     = col;
    return out;
}

fragment float4 particle_frag(ParticleOut in    [[stage_in]],
                               float2      coord [[point_coord]]) {
    float d = length(coord - 0.5);
    if (d > 0.5) discard_fragment();
    float a    = smoothstep(0.5, 0.08, d) * in.alpha;
    float core = smoothstep(0.10, 0.0, d) * 0.5;
    return float4(in.color + core, a + core * in.alpha);
}
