#include <metal_stdlib>
using namespace metal;

// MARK: - Particle Forge (Holographic)
//
// Two render layers (drawn in one pass):
//   1. Wireframe lines tracing the dumbbell skeleton (cyan, faint, fades
//      out during text shapes). Renders FIRST so particles glow on top.
//   2. ~8000 point-sprite particles spring-physics'd toward target points
//      sampled from one of 5 shapes (dumbbell / Scan. / Plan. / Compete. /
//      dumbbell). Holographic cyan palette + scan beam pulse.
//
// Stage state machine (USTAGE):
//   0  ASSEMBLING   1  IDLE         2  BURSTING
//   3  MORPH_SCAN   4  HOLD_SCAN
//   5  MORPH_PLAN   6  HOLD_PLAN
//   7  MORPH_COMPETE 8 HOLD_COMPETE
//   9  MORPH_FINAL  10 IDLE_FINAL

struct PFParticle {
    float4 posSize;
    float4 velPhase;
};

struct PFUniforms {
    float4   tStuff;       // (time, dt, stage, dragProgress)
    float4   camFov;       // cam.xyz + fovHalf
    float4   resAspect;    // (resW, resH, aspect, particleCount)
    float4   extra;        // (wireAlpha, stageElapsed, beamActive, dragLift)
    float4   morph;        // (srcIdx, dstIdx, morphProgress, scatter)
    float4   shapeOffset;  // lerped world translation for current shape
    float4x4 dumbbellRot;
};

#define UTIME         u.tStuff.x
#define UDT           u.tStuff.y
#define USTAGE        u.tStuff.z
#define UDRAG         u.tStuff.w

#define UCAMPOS       u.camFov.xyz
#define UFOVHALF      u.camFov.w

#define URES          u.resAspect.xy
#define UCOUNT        u.resAspect.w

#define UWIREALPHA    u.extra.x
#define USTAGEELAPSED u.extra.y
#define UBEAMACTIVE   u.extra.z
#define UDRAGLIFT     u.extra.w

// MARK: - Compute step (particle physics)

kernel void pf_step(
    device PFParticle*         particles [[buffer(0)]],
    constant float4*           targets   [[buffer(1)]],
    constant PFUniforms&       u         [[buffer(2)]],
    uint                       id        [[thread_position_in_grid]]
) {
    if (float(id) >= UCOUNT) return;

    PFParticle p = particles[id];

    uint count  = uint(UCOUNT);
    uint srcIdx = uint(u.morph.x);
    uint dstIdx = uint(u.morph.y);
    float prog  = u.morph.z;
    float scatter = u.morph.w;

    bool isMorphing = (USTAGE > 2.5 && USTAGE < 3.5)
                   || (USTAGE > 4.5 && USTAGE < 5.5)
                   || (USTAGE > 6.5 && USTAGE < 7.5)
                   || (USTAGE > 8.5 && USTAGE < 9.5);

    // Per-particle progress jitter — only during active morph stages.
    // OUTSIDE of morphs we kill the jitter so every particle arrives
    // exactly at its target, otherwise stragglers (jitter < 0) stay
    // partway between src/dst forever, smearing letter strokes.
    float jProg;
    if (isMorphing) {
        float jitterHash = fract(sin(float(id) * 78.233) * 43758.5453);
        float jitter = (jitterHash - 0.5) * 0.18;
        jProg = clamp(prog + jitter, 0.0, 1.0);
    } else {
        jProg = prog;
    }

    float3 srcT = targets[srcIdx * count + id].xyz;
    float3 dstT = targets[dstIdx * count + id].xyz;
    float3 baseTarget = mix(srcT, dstT, jProg);

    if (scatter > 0.001) {
        float3 dir = baseTarget;
        float dist = length(dir);
        if (dist > 0.001) {
            dir /= dist;
            baseTarget += dir * scatter;
        }
    }

    float4 rotTarget = u.dumbbellRot * float4(baseTarget, 1.0);
    float3 target = rotTarget.xyz + u.shapeOffset.xyz;

    float3 toTarget = target - p.posSize.xyz;

    float settle = p.velPhase.w;
    float stiffness = mix(7.0, 22.0, settle);
    float damping   = mix(0.94, 0.90, settle);

    if (USTAGE > 1.5 && USTAGE < 2.5) {
        // Bursting — weak spring + radial outward + drag-lift.
        stiffness *= 0.06;
        damping = 0.96;
        float3 fromCenter = p.posSize.xyz;
        float dist = max(0.5, length(fromCenter));
        fromCenter /= dist;
        float burstStrength = 14.0 * UDRAG;
        p.velPhase.xyz += fromCenter * burstStrength * UDT;
        p.velPhase.xyz += float3(0.0, UDRAGLIFT, 0.0) * UDT;
    } else if (isMorphing) {
        // Softer spring + slightly lower damping during morph so particles
        // drift smoothly rather than snap. Critical-damped feel.
        stiffness *= 0.55;
        damping = 0.93;
    }

    float3 force = toTarget * stiffness;

    // Idle jitter — kept very gentle so the dumbbell silhouette stays
    // crisp (was 1.4 force which displaced particles ~6% of plate radius
    // and read as fuzzy). 0.45 keeps a barely-perceptible "alive" wobble
    // while particles cling tightly to their target points.
    bool isDumbbellIdle = (USTAGE > 0.5 && USTAGE < 1.5) || (USTAGE > 9.5);
    bool isTextHold     = (USTAGE > 3.5 && USTAGE < 4.5)
                       || (USTAGE > 5.5 && USTAGE < 6.5)
                       || (USTAGE > 7.5 && USTAGE < 8.5);
    if ((isDumbbellIdle || isTextHold) && settle > 0.7) {
        float fid = float(id);
        float n1 = sin(UTIME * 1.30 + fid * 0.731);
        float n2 = cos(UTIME * 1.70 + fid * 0.413);
        float n3 = sin(UTIME * 1.10 + fid * 0.957);
        float jitterAmt = isDumbbellIdle ? 0.45 : 0.25;
        force += float3(n1, n2, n3) * jitterAmt;
    }

    p.velPhase.xyz += force * UDT;
    p.velPhase.xyz *= damping;
    p.posSize.xyz  += p.velPhase.xyz * UDT;

    if (USTAGE > 1.5 && USTAGE < 2.5) {
        p.velPhase.w = clamp(p.velPhase.w - UDT * 1.5, 0.30, 1.0);
    } else if (isMorphing) {
        p.velPhase.w = clamp(p.velPhase.w - UDT * 0.55, 0.45, 1.0);
    } else {
        // Faster settle so particles fully lock to target within the hold
        // window — was 0.85/sec which left letters mid-formation in a 0.4s
        // hold. At 1.8/sec a particle goes from 0.45 → 1.0 in ~0.3s.
        p.velPhase.w = clamp(p.velPhase.w + UDT * 1.8, 0.0, 1.0);
    }

    particles[id] = p;
}

// MARK: - Particle render

struct VOut {
    float4 position  [[position]];
    float  pointSize [[point_size]];
    float  alpha;
    float  glow;
    float  warm;
    float  beamHit;
};

vertex VOut pf_vert(
    uint                     vid       [[vertex_id]],
    constant PFParticle*     particles [[buffer(0)]],
    constant PFUniforms&     u         [[buffer(1)]]
) {
    PFParticle p = particles[vid];
    float3 view = p.posSize.xyz - UCAMPOS;
    float invZ = 1.0 / max(0.05, -view.z);
    float fovScale = 1.0 / tan(UFOVHALF);
    float aspect = URES.x / URES.y;

    float2 ndc;
    ndc.x = view.x * invZ * fovScale / aspect;
    ndc.y = view.y * invZ * fovScale;

    VOut o;
    o.position = float4(ndc, 0, 1);

    // Slightly smaller particles so wireframe lines + letter strokes stay
    // legible. Settled particles shrink further (mix 2.4 → 0.85) for crisp
    // dot-matrix feel during text holds.
    float baseSize = URES.y * 0.017;
    float sz = baseSize * fovScale * invZ;

    float settle = p.velPhase.w;
    sz *= mix(2.4, 0.85, settle);

    o.pointSize = clamp(sz, 1.5, 70.0);
    o.alpha     = mix(0.85, 1.0, settle);
    o.glow      = mix(1.7, 1.0, settle);

    float h = fract(sin(float(vid) * 12.9898) * 43758.5453);
    o.warm = h;

    float beamPeriod = 4.0;
    float bt = fract(UTIME / beamPeriod);
    float beamX = mix(-2.6, 2.6, bt < 0.5 ? bt * 2.0 : (1.0 - bt) * 2.0);
    float dx = (p.posSize.x - beamX) / 0.45;
    o.beamHit = exp(-dx * dx) * UBEAMACTIVE;

    return o;
}

fragment float4 pf_frag(VOut in [[stage_in]],
                         float2 coord [[point_coord]]) {
    float d = length(coord - 0.5);
    if (d > 0.5) discard_fragment();

    // Tighter core, weaker halo — soft halos were smearing letter edges
    // when particles were standing in for text strokes.
    float core = exp(-d * d * 26.0);
    float halo = exp(-d * d * 5.5) * 0.13;
    float a = (core + halo) * in.alpha;

    // Holographic palette — pale cyan-white core, deeper cyan tint variation.
    float3 hot  = float3(0.92, 1.00, 1.10);
    float3 cool = float3(0.50, 0.85, 1.20);
    float3 base = mix(cool, hot, in.warm);

    float3 beamTint = float3(0.55, 0.95, 1.20);
    float3 col = base * in.glow;
    col += beamTint * in.beamHit * 1.6;

    float aOut = a + a * in.beamHit * 0.8;

    return float4(col * aOut, aOut);
}

