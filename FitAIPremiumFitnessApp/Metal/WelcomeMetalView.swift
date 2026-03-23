import SwiftUI
import MetalKit
import SceneKit

// MARK: - Shared Uniforms (must match WelcomeShader.metal struct Uniforms)

struct WelcomeMTLUniforms {
    var time:       Float
    var resolution: SIMD2<Float>
}

// MARK: - Metal Renderer

final class WelcomeRenderer: NSObject, MTKViewDelegate {

    private let device:          MTLDevice
    private let commandQueue:    MTLCommandQueue
    private let bgPipeline:      MTLRenderPipelineState
    private let particlePipeline: MTLRenderPipelineState
    private let particleBuffer:  MTLBuffer
    private let particleCount    = 90
    private let startTime        = Date()

    init?(mtkView view: MTKView) {
        guard
            let dev   = MTLCreateSystemDefaultDevice(),
            let queue = dev.makeCommandQueue(),
            let lib   = dev.makeDefaultLibrary()
        else { return nil }

        device       = dev
        commandQueue = queue

        view.device             = dev
        view.colorPixelFormat   = .bgra8Unorm
        view.clearColor         = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.isPaused           = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60
        view.backgroundColor    = .black

        // ── Background pipeline ──
        let bgDesc = MTLRenderPipelineDescriptor()
        bgDesc.label             = "Background"
        bgDesc.vertexFunction    = lib.makeFunction(name: "bg_vert")
        bgDesc.fragmentFunction  = lib.makeFunction(name: "bg_frag")
        bgDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let bg = try? dev.makeRenderPipelineState(descriptor: bgDesc) else { return nil }
        bgPipeline = bg

        // ── Particle pipeline (additive blend) ──
        let pDesc = MTLRenderPipelineDescriptor()
        pDesc.label            = "Particles"
        pDesc.vertexFunction   = lib.makeFunction(name: "particle_vert")
        pDesc.fragmentFunction = lib.makeFunction(name: "particle_frag")
        pDesc.colorAttachments[0].pixelFormat           = .bgra8Unorm
        pDesc.colorAttachments[0].isBlendingEnabled     = true
        pDesc.colorAttachments[0].sourceRGBBlendFactor  = .sourceAlpha
        pDesc.colorAttachments[0].destinationRGBBlendFactor = .one   // additive
        pDesc.colorAttachments[0].sourceAlphaBlendFactor    = .sourceAlpha
        pDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
        guard let pp = try? dev.makeRenderPipelineState(descriptor: pDesc) else { return nil }
        particlePipeline = pp

        // ── Particle data: float4(normX, normY, phase, size) ──
        var data = [SIMD4<Float>]()
        data.reserveCapacity(particleCount)
        for _ in 0..<90 {
            data.append(SIMD4<Float>(
                Float.random(in: 0...1),
                Float.random(in: 0...1),
                Float.random(in: 0...(Float.pi * 6)),
                Float.random(in: 0.8...2.8)
            ))
        }
        guard let pb = dev.makeBuffer(
            bytes: data,
            length: MemoryLayout<SIMD4<Float>>.stride * 90,
            options: .storageModeShared
        ) else { return nil }
        particleBuffer = pb

        super.init()
        view.delegate = self
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let rpd      = view.currentRenderPassDescriptor,
            let cmdBuf   = commandQueue.makeCommandBuffer(),
            let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
        else { return }

        var uniforms = WelcomeMTLUniforms(
            time: Float(Date().timeIntervalSince(startTime)),
            resolution: SIMD2<Float>(
                Float(view.drawableSize.width),
                Float(view.drawableSize.height)
            )
        )

        // ── Draw background ──
        enc.setRenderPipelineState(bgPipeline)
        enc.setFragmentBytes(&uniforms,
                             length: MemoryLayout<WelcomeMTLUniforms>.stride,
                             index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        // ── Draw particles ──
        enc.setRenderPipelineState(particlePipeline)
        enc.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        enc.setVertexBytes(&uniforms,
                           length: MemoryLayout<WelcomeMTLUniforms>.stride,
                           index: 1)
        enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)

        enc.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}

// MARK: - WelcomeMetalView (UIViewRepresentable)

struct WelcomeMetalView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.backgroundColor = .black
        context.coordinator.renderer = WelcomeRenderer(mtkView: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    final class Coordinator {
        var renderer: WelcomeRenderer?
    }
}

// MARK: - DumbbellSceneView  (SceneKit 3-D, matching website geometry)

struct DumbbellSceneView: UIViewRepresentable {

    func makeUIView(context: Context) -> SCNView {
        let scnView                     = SCNView()
        scnView.backgroundColor         = .clear
        scnView.allowsCameraControl     = false
        scnView.antialiasingMode        = .multisampling4X
        scnView.rendersContinuously     = true
        scnView.autoenablesDefaultLighting = false
        scnView.scene                   = Self.buildScene()
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: Scene construction
    static func buildScene() -> SCNScene {
        let scene = SCNScene()

        // ── Camera ──
        let camNode     = SCNNode()
        camNode.camera  = SCNCamera()
        camNode.camera?.fieldOfView = 42
        camNode.position            = SCNVector3(0, 0.05, 3.4)
        scene.rootNode.addChildNode(camNode)

        // ── Lights ──
        let ambient         = SCNNode()
        ambient.light       = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.18, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key             = SCNNode()
        key.light           = SCNLight()
        key.light?.type     = .directional
        key.light?.color    = UIColor.white
        key.light?.intensity = 900
        key.eulerAngles     = SCNVector3(-0.8, 0.4, 0)
        scene.rootNode.addChildNode(key)

        let fill            = SCNNode()
        fill.light          = SCNLight()
        fill.light?.type    = .directional
        fill.light?.color   = UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1)
        fill.light?.intensity = 400
        fill.eulerAngles    = SCNVector3(0.2, -1.2, 0)
        scene.rootNode.addChildNode(fill)

        let rim             = SCNNode()
        rim.light           = SCNLight()
        rim.light?.type     = .directional
        rim.light?.color    = UIColor(white: 0.6, alpha: 1)
        rim.light?.intensity = 300
        rim.eulerAngles     = SCNVector3(Float.pi * 0.3, Float.pi, 0)
        scene.rootNode.addChildNode(rim)

        // ── Materials ──
        let chrome = Self.makeMaterial(diffuse: 0.92, metalness: 1.0, roughness: 0.06)
        let darkPlate = Self.makeMaterial(diffuse: 0.70, metalness: 1.0, roughness: 0.12)
        let grip = Self.makeMaterial(diffuse: 0.45, metalness: 0.8, roughness: 0.35)
        let edge = Self.makeMaterial(diffuse: 0.85, metalness: 1.0, roughness: 0.08)

        // ── Dumbbell group ──
        let db = SCNNode()

        // Helper: horizontal cylinder at position x
        func cyl(_ r: Float, _ h: Float, _ mat: SCNMaterial, _ x: Float) {
            let geo   = SCNCylinder(radius: CGFloat(r), height: CGFloat(h))
            geo.radialSegmentCount = 64
            geo.materials = [mat]
            let node  = SCNNode(geometry: geo)
            node.eulerAngles.z = Float.pi / 2
            node.position      = SCNVector3(x, 0, 0)
            db.addChildNode(node)
        }

        // Torus ring accent on plate face
        func ring(_ r: Float, _ tube: Float, _ mat: SCNMaterial, _ x: Float) {
            let geo = SCNTorus(ringRadius: CGFloat(r), pipeRadius: CGFloat(tube))
            geo.ringSegmentCount = 80
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.eulerAngles.y = Float.pi / 2
            node.position      = SCNVector3(x, 0, 0)
            db.addChildNode(node)
        }

        // ── Bar & grip (matching website) ──
        cyl(0.048, 4.40, chrome, 0)          // main bar
        cyl(0.072, 1.30, grip,   0)          // grip knurl

        // ── Build one side, mirror for other ──
        func buildSide(_ s: Float) {
            cyl(0.085, 0.10, edge,      s * 0.71)   // inner collar
            cyl(0.095, 0.14, edge,      s * 0.86)   // spacer
            cyl(0.520, 0.13, chrome,    s * 1.00)   // plate 1 (main)
            cyl(0.520, 0.13, darkPlate, s * 1.14)   // plate 2 (darker)
            cyl(0.420, 0.10, chrome,    s * 1.26)   // plate 3
            cyl(0.320, 0.09, darkPlate, s * 1.36)   // plate 4
            cyl(0.110, 0.18, edge,      s * 1.46)   // end cap
            ring(0.520, 0.013, edge,    s * 1.00)   // ring accent
        }
        buildSide( 1)
        buildSide(-1)

        // ── Initial orientation (matches website) ──
        db.eulerAngles = SCNVector3(-0.08, 0.22, -0.10)

        // ── Float animation ──
        let up   = SCNAction.moveBy(x: 0, y: 0.10, z: 0, duration: 2.8)
        up.timingMode   = .easeInEaseOut
        let down = SCNAction.moveBy(x: 0, y: -0.10, z: 0, duration: 2.8)
        down.timingMode = .easeInEaseOut
        db.runAction(.repeatForever(.sequence([up, down])))

        // ── Slow Y rotation ──
        db.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat(Float.pi * 2), z: 0, duration: 22)))

        scene.rootNode.addChildNode(db)
        return scene
    }

    private static func makeMaterial(diffuse: CGFloat,
                                     metalness: CGFloat,
                                     roughness: CGFloat) -> SCNMaterial {
        let m                   = SCNMaterial()
        m.lightingModel         = .physicallyBased
        m.diffuse.contents      = UIColor(white: diffuse, alpha: 1)
        m.metalness.contents    = metalness
        m.roughness.contents    = roughness
        m.fresnelExponent       = 4
        return m
    }
}
