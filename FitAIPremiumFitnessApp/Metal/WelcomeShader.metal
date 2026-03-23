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
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        p  = rot * p * 2.1;
        a *= 0.5;
    }
    return v;
}

static float3 iridescentColor(float hue) {
    return float3(
        0.5 + 0.5 * cos(hue * 6.2831 + 0.0),
        0.5 + 0.5 * cos(hue * 6.2831 + 2.094),
        0.5 + 0.5 * cos(hue * 6.2831 + 4.189)
    );
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
    uv.y       = 1.0 - uv.y;          // flip: 0=bottom, 1=top
    float2 uvC = uv - 0.5;
    float t    = u.time;

    // --- Layered noise ---
    float n1 = fbm(uv * 2.2 + float2(t * 0.04, t * 0.03));
    float n2 = fbm(uv * 5.0 - float2(t * 0.03, t * 0.05) + n1 * 0.35);
    float n3 = fbm(uv * 9.0 + float2(t * 0.06, -t * 0.04) + n2 * 0.2);

    // --- Base dark colour ---
    float3 col = float3(0.018, 0.018, 0.022) + float3(n2 * 0.038, n2 * 0.030, n2 * 0.050);

    // --- Iridescent layer ---
    float iriDrive = fbm(uv * 3.5 + float2(t * 0.07, t * 0.05));
    float hue = iriDrive * 1.4 + uv.x * 0.6 + uv.y * 0.3 + t * 0.035;
    float3 iri = iridescentColor(hue);
    float iriMask = smoothstep(0.0, 1.0, n1 * n3 * 2.5);
    col = mix(col, col + iri * 0.14, iriMask);

    // --- Liquid shimmer streaks ---
    float streak1 = exp(-abs(sin(uv.x * 4.0 + t * 0.3 + n1) * 8.0)) * 0.06;
    float streak2 = exp(-abs(sin(uv.x * 7.0 - t * 0.2 + n2) * 12.0)) * 0.04;
    col += iridescentColor(hue + 0.3) * streak1;
    col += iridescentColor(hue + 0.6) * streak2;

    // --- Scan glow lines (2 sweeps, different speeds & colours) ---
    float s1 = fract(uv.y - t * 0.11);
    col += float3(0.25, 0.50, 1.00) * exp(-s1 * 16.0) * 0.20;

    float s2 = fract(uv.y - t * 0.28 + 0.55);
    col += float3(1.00, 0.88, 0.60) * exp(-s2 * 32.0) * 0.10;

    float s3 = fract(uv.y - t * 0.07 + 0.27);
    col += float3(0.70, 0.35, 1.00) * exp(-s3 * 48.0) * 0.07;

    // --- Horizontal grid lines (subtle) ---
    float grid = abs(sin(uv.y * u.resolution.y * 0.5)) ;
    col += float3(0.1, 0.15, 0.25) * smoothstep(0.98, 1.0, grid) * 0.03;

    // --- Vignette ---
    float vign = 1.0 - smoothstep(0.25, 0.85, length(uvC * float2(1.0, 1.5)));
    col *= vign;

    // --- Film grain ---
    float grain = fract(sin(dot(in.position.xy + t * 17.3, float2(12.9898, 78.233))) * 43758.5);
    col += (grain - 0.5) * 0.020;

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
    float  py = p.y + sin(u.time * 0.45 + p.z) * 0.028;
    float  alpha = (sin(u.time * 0.7 + p.z) + 1.0) * 0.5 * 0.42 + 0.04;

    // Per-particle iridescent tint
    float hue = p.z * 0.9 + u.time * 0.06;
    float3 col = float3(
        0.72 + 0.28 * cos(hue * 2.5 + 0.0),
        0.72 + 0.28 * cos(hue * 2.5 + 2.094),
        0.88 + 0.12 * cos(hue * 2.5 + 4.189)
    );

    ParticleOut out;
    out.position  = float4(px * 2.0 - 1.0, -(py * 2.0 - 1.0), 0, 1);
    out.pointSize = p.w * u.resolution.y * 0.007;
    out.alpha     = alpha;
    out.color     = col;
    return out;
}

fragment float4 particle_frag(ParticleOut in    [[stage_in]],
                               float2      coord [[point_coord]]) {
    float d = length(coord - 0.5);
    if (d > 0.5) discard_fragment();
    // Soft glow falloff
    float a = smoothstep(0.5, 0.05, d) * in.alpha;
    // Small bright core
    float core = smoothstep(0.12, 0.0, d) * 0.6;
    return float4(in.color + core, a + core * in.alpha);
}
