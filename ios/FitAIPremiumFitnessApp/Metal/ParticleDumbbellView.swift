import SwiftUI
import MetalKit
import simd
import CoreMotion

// MARK: - Stage state machine

/// Drives the particle simulation's phase. Transitioned by SwiftUI in
/// response to user input + scheduled timers; renderer reads the current
/// stage to choose src/dst targets, morph progress, scatter, and rotation
/// behavior. Raw values are passed straight to the shader as `USTAGE`.
enum ParticleStage: Int, Equatable {
    case assembling   = 0   // particles flying in, target = dumbbell-low
    case idle         = 1   // settled at dumbbell-low, scan beam, awaits swipe
    case bursting     = 2   // user dragging — radial outward force
    case morphScan    = 3   // morphing dumbbell-low → "Scan."
    case holdScan     = 4   // settled at "Scan."
    case morphPlan    = 5   // "Scan." → "Plan."
    case holdPlan     = 6
    case morphCompete = 7   // "Plan." → "Compete."
    case holdCompete  = 8
    case morphFinal   = 9   // "Compete." → dumbbell-high (the dramatic one)
    case idleFinal    = 10  // final dumbbell, hero text revealed alongside
}

private extension ParticleStage {
    /// Source shape index in the unified target buffer.
    var srcIdx: Int {
        switch self {
        case .assembling, .idle, .bursting, .morphScan: return 0  // dumbbell-low
        case .holdScan, .morphPlan: return 1
        case .holdPlan, .morphCompete: return 2
        case .holdCompete, .morphFinal: return 3
        case .idleFinal: return 4  // dumbbell-high
        }
    }
    /// Destination shape index — what the morph (or hold) is converging to.
    var dstIdx: Int {
        switch self {
        case .assembling, .idle, .bursting: return 0
        case .morphScan, .holdScan: return 1
        case .morphPlan, .holdPlan: return 2
        case .morphCompete, .holdCompete: return 3
        case .morphFinal, .idleFinal: return 4
        }
    }
    /// Is this a morph stage (progress is animating, not pinned at 1)?
    var isMorphing: Bool {
        switch self {
        case .morphScan, .morphPlan, .morphCompete, .morphFinal: return true
        default: return false
        }
    }
    /// How long the morph stage runs in seconds. Bumped from earlier 0.55
    /// to give particles more time to drift gracefully (smoother feel).
    var morphDuration: TimeInterval {
        self == .morphFinal ? 0.95 : 0.75
    }
    /// Peak scatter (radial outward bloom) during morph. Final transition
    /// gets a full burst; word-to-word transitions are subtle "reorganize".
    var scatterPeak: Float {
        self == .morphFinal ? 0.85 : 0.20
    }
}

/// Uniform scale baked into the dumbbell point cloud. 0.28 sits the
/// dumbbell well inside the scan-frame brackets — small focal element
/// that nests between the Scan / Plan headlines without competing.
private let dumbbellScale: Float = 0.28

/// World-space y-translation per shape. Each text word is positioned to
/// land at the SAME screen Y where the static SwiftUI text will eventually
/// render — so during the morph cycle, particles materialize each word at
/// its final display position. Math: ndc.y = 1 - 2*(screenY/sh), then
/// world.y = ndc.y * 9 / 2.9 + 0.3 (camera at y=0.3, depth 9, FOV 38°).
///   • Scan above scan frame  → screenY ≈ sh*0.27 → world.y ≈ +1.70
///   • Plan inside scan frame → screenY ≈ sh*0.42 → world.y ≈ +0.80
///   • Compete below frame    → screenY ≈ sh*0.57 → world.y ≈ -0.10
private let shapeYOffsets: [Float] = [
    -1.40,  // 0 dumbbell-low (lower third — initial state)
     1.70,  // 1 Scan.   (above scan frame brackets)
     0.80,  // 2 Plan.   (inside scan frame brackets)
    -0.10,  // 3 Compete. (below scan frame brackets)
     1.05,  // 4 dumbbell-high (sits between Scan and Plan in the final state)
]

// MARK: - View

/// Particle-forge welcome hero — full-screen MTKView. ~8000 particles
/// physics-spring through 5 target shapes (dumbbell + 3 words + dumbbell)
/// driven by `stage` from SwiftUI. Gyro tilt for parallax. Scan beam pulses
/// during idle stages. Drag bursts particles outward.
struct ParticleDumbbellView: UIViewRepresentable {
    @Binding var stage: ParticleStage
    @Binding var dragProgress: CGFloat

    func makeCoordinator() -> ParticleDumbbellRenderer {
        ParticleDumbbellRenderer()
    }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = false
        // Critical: clear with full transparency so SwiftUI views layered
        // BEHIND the MTKView remain visible.
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        v.isOpaque = false
        v.backgroundColor = .clear
        v.layer.isOpaque = false
        v.preferredFramesPerSecond = 120
        v.delegate = context.coordinator
        context.coordinator.setup(view: v)
        context.coordinator.startMotion()
        return v
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.updateState(
            stage: stage,
            drag: Float(dragProgress)
        )
    }

    static func dismantleUIView(_ uiView: MTKView,
                                 coordinator: ParticleDumbbellRenderer) {
        coordinator.stopMotion()
    }
}

// MARK: - GPU types

private struct PFParticle {
    var posSize: SIMD4<Float>
    var velPhase: SIMD4<Float>
}

private struct PFUniforms {
    var tStuff:     SIMD4<Float>      // time, dt, stage, dragProgress
    var camFov:     SIMD4<Float>      // cam.xyz + fovHalf
    var resAspect:  SIMD4<Float>      // resW, resH, aspect, particleCount
    var extra:      SIMD4<Float>      // scale, stageElapsed, beamActive, dragLift
    var morph:      SIMD4<Float>      // srcIdx, dstIdx, morphProgress, scatter
    var shapeOffset: SIMD4<Float>     // lerped world translation
    var dumbbellRot: float4x4
}

// MARK: - Renderer

final class ParticleDumbbellRenderer: NSObject, MTKViewDelegate {

    private var device: MTLDevice!
    private var queue: MTLCommandQueue!
    private var stepPipeline: MTLComputePipelineState!
    private var renderPipeline: MTLRenderPipelineState!
    private var particleBuf: MTLBuffer!
    private var targetBuf: MTLBuffer!

    // Bumped from 8000 → 14000 for denser dumbbell silhouette + thicker
    // text strokes. Compute step is light, so 14k particles still runs
    // well under 1ms on iPhone GPU.
    private let particleCount = 14000
    private let shapeCount = 5
    private var startTime = CACurrentMediaTime()
    private var lastFrameTime: TimeInterval = 0

    // Stage tracking
    private var stage: ParticleStage = .assembling
    private var stageStartTime: TimeInterval = 0
    private var dragProgress: Float = 0

    // Smoothly interpolated render-side values.
    private var beamActive: Float = 0.0
    private var yRotAngle: Float = 0.0

    // Gyro
    private let motion = CMMotionManager()
    private var gyroPitch: Float = 0
    private var gyroYaw: Float = 0

    // MARK: Public state updates

    func updateState(stage newStage: ParticleStage, drag: Float) {
        if stage != newStage {
            stage = newStage
            stageStartTime = CACurrentMediaTime()
        }
        dragProgress = drag
    }

    func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let alpha: Float = 0.12
            self.gyroPitch += (Float(data.attitude.pitch) - self.gyroPitch) * alpha
            self.gyroYaw   += (Float(data.attitude.roll)  - self.gyroYaw)   * alpha
        }
    }

    func stopMotion() { motion.stopDeviceMotionUpdates() }

    // MARK: Setup

    func setup(view: MTKView) {
        guard let device = view.device else { return }
        self.device = device
        self.queue = device.makeCommandQueue()

        guard let lib = try? device.makeDefaultLibrary(bundle: .main),
              let stepFn = lib.makeFunction(name: "pf_step"),
              let vertFn = lib.makeFunction(name: "pf_vert"),
              let fragFn = lib.makeFunction(name: "pf_frag") else { return }

        stepPipeline = try? device.makeComputePipelineState(function: stepFn)

        // Particle pipeline — additive bokeh point sprites.
        let rd = MTLRenderPipelineDescriptor()
        rd.vertexFunction = vertFn
        rd.fragmentFunction = fragFn
        rd.colorAttachments[0].pixelFormat = view.colorPixelFormat
        rd.colorAttachments[0].isBlendingEnabled = true
        rd.colorAttachments[0].rgbBlendOperation = .add
        rd.colorAttachments[0].alphaBlendOperation = .add
        rd.colorAttachments[0].sourceRGBBlendFactor = .one
        rd.colorAttachments[0].sourceAlphaBlendFactor = .one
        rd.colorAttachments[0].destinationRGBBlendFactor = .one
        rd.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        renderPipeline = try? device.makeRenderPipelineState(descriptor: rd)

        // Build all 5 target shapes. Each is exactly `particleCount` points.
        // Order matches `srcIdx` / `dstIdx` mapping in ParticleStage.
        var allTargets = [SIMD4<Float>]()
        allTargets.reserveCapacity(particleCount * shapeCount)
        // Two dumbbells (low + high) share the same canonical sampling; the
        // y-offset is applied via shapeOffset uniform, not baked.
        let dumbbellPts = generateDumbbellTargets(total: particleCount,
                                                    scale: dumbbellScale)
        // Text widths bumped ~1.5x for bigger, more readable letters during
        // the morph cycle. Compete is naturally longer so it extends past
        // the scan-frame brackets a bit — readable trumps containment.
        let scanPts     = sampleTextPoints("Scan.",     count: particleCount, worldWidth: 1.60)
        let planPts     = sampleTextPoints("Plan.",     count: particleCount, worldWidth: 1.60)
        let competePts  = sampleTextPoints("Compete.",  count: particleCount, worldWidth: 2.10)

        allTargets.append(contentsOf: dumbbellPts)   // 0 dumbbell-low
        allTargets.append(contentsOf: scanPts)       // 1 Scan.
        allTargets.append(contentsOf: planPts)       // 2 Plan.
        allTargets.append(contentsOf: competePts)    // 3 Compete.
        allTargets.append(contentsOf: dumbbellPts)   // 4 dumbbell-high (same canonical points)

        // Particles spawn on a sphere of radius 11–18, biased toward camera.
        // Larger radius for full-screen so they stream from real edges.
        var particles = [PFParticle]()
        particles.reserveCapacity(particleCount)
        for _ in 0..<particleCount {
            let theta = Float.random(in: 0..<(2 * .pi))
            let phi = acos(Float.random(in: -1...1))
            let r = Float.random(in: 11...18)
            let sx = r * sin(phi) * cos(theta)
            let sy = r * sin(phi) * sin(theta)
            let sz = r * cos(phi) - 2

            let inward = -normalize(SIMD3(sx, sy, sz))
            let vmag = Float.random(in: 0.4...1.4)

            particles.append(PFParticle(
                posSize: SIMD4(sx, sy, sz, 0),
                velPhase: SIMD4(inward.x * vmag, inward.y * vmag, inward.z * vmag, 0)
            ))
        }

        particleBuf = device.makeBuffer(
            bytes: particles,
            length: MemoryLayout<PFParticle>.stride * particleCount,
            options: [.storageModeShared]
        )
        targetBuf = device.makeBuffer(
            bytes: allTargets,
            length: MemoryLayout<SIMD4<Float>>.stride * allTargets.count,
            options: [.storageModeShared]
        )

        startTime = CACurrentMediaTime()
        stageStartTime = startTime
    }

    // MARK: Draw

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let stepPipeline = stepPipeline,
              let renderPipeline = renderPipeline,
              let particleBuf = particleBuf,
              let targetBuf = targetBuf,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer() else { return }

        let now = CACurrentMediaTime()
        let dt = Float(min(0.04,
                           lastFrameTime == 0 ? 0.016 : now - lastFrameTime))
        lastFrameTime = now
        let t = Float(now - startTime)
        let stageElapsed = Float(now - stageStartTime)

        // Auto-advance assembling → idle once particles have had time to
        // converge. Swift drives all subsequent transitions via @State.
        if stage == .assembling && stageElapsed > 1.6 {
            stage = .idle
            stageStartTime = now
        }

        // Morph progress + scatter pulse — only meaningful during morph
        // stages; otherwise pinned at (prog=1, scatter=0) so the spring
        // converges to the dst target.
        var morphProgress: Float = 1.0
        var scatter: Float = 0.0
        if stage.isMorphing {
            let dur = Float(stage.morphDuration)
            let raw = max(0, min(1, stageElapsed / dur))
            // Ease in-out cubic for graceful arrival.
            morphProgress = raw < 0.5
                ? 4 * raw * raw * raw
                : 1 - pow(-2 * raw + 2, 3) / 2
            // Triangle-wave scatter: 0 → peak → 0 across the morph.
            scatter = sin(raw * Float.pi) * stage.scatterPeak
        }

        // Beam fades in during pure idle stages, off otherwise.
        let beamTarget: Float = {
            switch stage {
            case .idle, .holdScan, .holdPlan, .holdCompete, .idleFinal: return 1.0
            default: return 0.0
            }
        }()
        beamActive += (beamTarget - beamActive) * min(1, dt * 3.0)

        let dragLift: Float = (stage == .bursting) ? dragProgress * 9.0 : 0.0

        // Y-spin advances only during dumbbell-anchored idle stages. Otherwise
        // ease back toward 0 so text appears facing the camera (not skewed by
        // a half-rotation captured at morph time).
        let wantsFreeSpin = (stage == .assembling || stage == .idle || stage == .idleFinal)
        if wantsFreeSpin {
            yRotAngle += dt * 0.22
        } else {
            yRotAngle += (0 - yRotAngle) * min(1, dt * 4.0)
        }

        // Gyro parallax + slight static tilt + (optional) Y-spin.
        let yRot = rotY(yRotAngle)
        let gyroRot = rotX(gyroPitch * 0.28) * rotY(gyroYaw * 0.22)
        let staticTilt = rotX(-0.05) * rotZ(-0.06)
        let dumbbellRot = gyroRot * staticTilt * yRot

        // Lerp shape y-offset between src and dst so the dumbbell smoothly
        // travels from low → center (during morphScan) and center → high
        // (during morphFinal).
        let srcOffsetY = shapeYOffsets[stage.srcIdx]
        let dstOffsetY = shapeYOffsets[stage.dstIdx]
        let lerpedOffsetY = simd_mix(srcOffsetY, dstOffsetY, morphProgress)

        let drawSize = view.drawableSize
        let aspect = drawSize.width > 0 && drawSize.height > 0
            ? Float(drawSize.width / drawSize.height) : 1
        var uni = PFUniforms(
            tStuff: SIMD4(t, dt, Float(stage.rawValue), dragProgress),
            camFov: SIMD4(0, 0.3, 9, Float(38.0 * .pi / 180.0) * 0.5),
            resAspect: SIMD4(Float(drawSize.width),
                              Float(drawSize.height),
                              aspect, Float(particleCount)),
            extra: SIMD4(0, stageElapsed, beamActive, dragLift),
            morph: SIMD4(Float(stage.srcIdx),
                          Float(stage.dstIdx),
                          morphProgress, scatter),
            shapeOffset: SIMD4(0, lerpedOffsetY, 0, 0),
            dumbbellRot: dumbbellRot
        )

        // Compute step
        if let cenc = cmd.makeComputeCommandEncoder() {
            cenc.setComputePipelineState(stepPipeline)
            cenc.setBuffer(particleBuf, offset: 0, index: 0)
            cenc.setBuffer(targetBuf, offset: 0, index: 1)
            cenc.setBytes(&uni, length: MemoryLayout<PFUniforms>.stride, index: 2)

            let groupSize = max(1, stepPipeline.threadExecutionWidth)
            let groupCount = (particleCount + groupSize - 1) / groupSize
            cenc.dispatchThreadgroups(
                MTLSize(width: groupCount, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: groupSize, height: 1, depth: 1)
            )
            cenc.endEncoding()
        }

        // Render — particle point sprites only (wireframe was removed since
        // SCNView dumbbells layered behind cover the start/end states).
        if let renc = cmd.makeRenderCommandEncoder(descriptor: pass) {
            renc.setRenderPipelineState(renderPipeline)
            renc.setVertexBuffer(particleBuf, offset: 0, index: 0)
            renc.setVertexBytes(&uni, length: MemoryLayout<PFUniforms>.stride, index: 1)
            renc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
            renc.endEncoding()
        }

        cmd.present(drawable)
        cmd.commit()
    }

    // MARK: - Dumbbell surface sampling

    private struct Prim {
        let radius: Float
        let length: Float
        let x: Float
        let sample: SamplingMode
    }
    private enum SamplingMode { case sideOnly, all }

    private func generateDumbbellTargets(total: Int, scale: Float) -> [SIMD4<Float>] {
        var prims: [Prim] = [
            Prim(radius: 0.048, length: 4.4, x: 0,    sample: .sideOnly),
            Prim(radius: 0.072, length: 1.3, x: 0,    sample: .sideOnly),
            Prim(radius: 0.085, length: 0.10, x:  0.71, sample: .all),
            Prim(radius: 0.085, length: 0.10, x: -0.71, sample: .all),
        ]
        for s in [Float(1), Float(-1)] {
            prims.append(contentsOf: [
                Prim(radius: 0.095, length: 0.14, x: s * 0.86, sample: .all),
                Prim(radius: 0.52,  length: 0.13, x: s * 1.00, sample: .all),
                Prim(radius: 0.52,  length: 0.13, x: s * 1.14, sample: .all),
                Prim(radius: 0.42,  length: 0.10, x: s * 1.26, sample: .all),
                Prim(radius: 0.32,  length: 0.09, x: s * 1.36, sample: .all),
                Prim(radius: 0.11,  length: 0.18, x: s * 1.46, sample: .all),
            ])
        }

        let areas: [Float] = prims.map { p in
            let sideArea = 2 * .pi * p.radius * p.length
            let capArea  = .pi * p.radius * p.radius
            return p.sample == .all ? sideArea + 2 * capArea : sideArea
        }
        let totalArea = areas.reduce(0, +)

        var points = [SIMD4<Float>]()
        points.reserveCapacity(total)

        for (i, p) in prims.enumerated() {
            let count = Int((Float(total) * areas[i] / totalArea).rounded())
            switch p.sample {
            case .sideOnly:
                points.append(contentsOf: sampleSide(p, count: count))
            case .all:
                let sideA = 2 * .pi * p.radius * p.length
                let capA  = .pi * p.radius * p.radius
                let totalA = sideA + 2 * capA
                let sideN = Int((Float(count) * sideA / totalA).rounded())
                let capN = max(0, (count - sideN) / 2)
                points.append(contentsOf: sampleSide(p, count: sideN))
                points.append(contentsOf: sampleCap(p, side: -1, count: capN))
                points.append(contentsOf: sampleCap(p, side: +1,
                                                     count: count - sideN - capN))
            }
        }

        while points.count < total {
            points.append(points[Int.random(in: 0..<points.count)])
        }
        if points.count > total { points = Array(points.prefix(total)) }
        points.shuffle()
        // Apply uniform scale (0.5 by default) so the dumbbell fits the
        // portrait phone screen with margin.
        return points.map { SIMD4($0.x * scale, $0.y * scale, $0.z * scale, 0) }
    }

    private func sampleSide(_ p: Prim, count: Int) -> [SIMD4<Float>] {
        (0..<count).map { _ in
            let theta = Float.random(in: 0..<(2 * .pi))
            let t = Float.random(in: -1...1)
            return SIMD4(p.x + p.length * 0.5 * t,
                          p.radius * cos(theta),
                          p.radius * sin(theta),
                          0)
        }
    }

    private func sampleCap(_ p: Prim, side: Int, count: Int) -> [SIMD4<Float>] {
        let xPos = p.x + p.length * 0.5 * Float(side)
        return (0..<count).map { _ in
            let r = p.radius * sqrt(Float.random(in: 0...1))
            let theta = Float.random(in: 0..<(2 * .pi))
            return SIMD4(xPos, r * cos(theta), r * sin(theta), 0)
        }
    }


    // MARK: - Text → point cloud
    //
    // Render `text` to a bitmap with a heavy display font, threshold the
    // pixels, and randomly sample `count` points from the lit pixels.
    // Those points get mapped from pixel coords to world coords centered
    // at origin with width = `worldWidth`.

    private func sampleTextPoints(_ text: String,
                                    count: Int,
                                    worldWidth: Float) -> [SIMD4<Float>] {
        let fontSize: CGFloat = 220
        // .heavy instead of .black — strokes one weight thinner so
        // letterforms read as crisp display type rather than blocky slabs.
        // Kern -3 (was -8) gives breathing room between glyphs.
        let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .kern: -3,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let padding: CGFloat = 12
        let bitmapSize = CGSize(width: textSize.width + padding * 2,
                                 height: textSize.height + padding * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: bitmapSize, format: format)
        let img = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: bitmapSize))
            attrStr.draw(at: CGPoint(x: padding, y: padding))
        }

        guard let cgImg = img.cgImage,
              let data = cgImg.dataProvider?.data else {
            return Array(repeating: SIMD4<Float>(0, 0, 0, 0), count: count)
        }
        let bytes = CFDataGetBytePtr(data)!
        let width = cgImg.width
        let height = cgImg.height
        let bytesPerPixel = cgImg.bitsPerPixel / 8
        let bytesPerRow = cgImg.bytesPerRow

        // Find lit pixels (white text on black background).
        var hits = [(x: Int, y: Int)]()
        hits.reserveCapacity(width * height / 8)
        for y in 0..<height {
            for x in 0..<width {
                let off = y * bytesPerRow + x * bytesPerPixel
                let r = Int(bytes[off])
                let g = Int(bytes[off + 1])
                let b = Int(bytes[off + 2])
                if (r + g + b) > 384 {  // brightness > 50%
                    hits.append((x, y))
                }
            }
        }

        if hits.isEmpty {
            return Array(repeating: SIMD4<Float>(0, 0, 0, 0), count: count)
        }

        let scale: Float = worldWidth / Float(width)
        let cx = Float(width) * 0.5
        let cy = Float(height) * 0.5

        var points = [SIMD4<Float>]()
        points.reserveCapacity(count)
        for _ in 0..<count {
            let pick = hits[Int.random(in: 0..<hits.count)]
            // Sub-pixel jitter so points don't form a discrete grid.
            let px = Float(pick.x) + Float.random(in: -0.5...0.5)
            let py = Float(pick.y) + Float.random(in: -0.5...0.5)
            let wx = (px - cx) * scale
            let wy = -(py - cy) * scale  // flip Y: pixel-y down → world-y up
            points.append(SIMD4(wx, wy, 0, 0))
        }
        return points
    }

    // MARK: - Matrix helpers

    private func rotX(_ a: Float) -> float4x4 {
        let c = cos(a), s = sin(a)
        return float4x4(
            SIMD4(1, 0, 0, 0),
            SIMD4(0, c, s, 0),
            SIMD4(0,-s, c, 0),
            SIMD4(0, 0, 0, 1)
        )
    }
    private func rotY(_ a: Float) -> float4x4 {
        let c = cos(a), s = sin(a)
        return float4x4(
            SIMD4(c, 0,-s, 0),
            SIMD4(0, 1, 0, 0),
            SIMD4(s, 0, c, 0),
            SIMD4(0, 0, 0, 1)
        )
    }
    private func rotZ(_ a: Float) -> float4x4 {
        let c = cos(a), s = sin(a)
        return float4x4(
            SIMD4( c, s, 0, 0),
            SIMD4(-s, c, 0, 0),
            SIMD4( 0, 0, 1, 0),
            SIMD4( 0, 0, 0, 1)
        )
    }
}
