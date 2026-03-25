import SwiftUI
import SceneKit
import CoreMotion

// MARK: - DumbbellSceneView
//
// transparent = true  → clear background, no fog, no floating plates/particles,
//                        no vertical-bob (used in SwipeUpSplashView)
// transparent = false → full dark scene matching the website (used in WelcomeView)

struct DumbbellSceneView: UIViewRepresentable {

    var transparent: Bool = false
    /// When true (light mode), use near-black chrome so it pops on white background
    var darkChrome:  Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor          = transparent ? .clear : .black
        v.isOpaque                 = !transparent
        v.allowsCameraControl      = false
        v.antialiasingMode         = .multisampling4X
        v.rendersContinuously      = true
        v.autoenablesDefaultLighting = false

        // Read trait collection directly — more reliable than SwiftUI @Environment in makeUIView
        let isLightMode = UITraitCollection.current.userInterfaceStyle != .dark
        let result = buildScene(transparent: transparent, darkChrome: transparent && isLightMode)
        v.scene    = result.scene
        v.delegate = context.coordinator

        let c = context.coordinator
        c.dbNode      = result.dbNode
        c.ghostDb     = result.ghostDb
        c.freePlates  = result.freePlates
        c.orbitPlates = result.orbitPlates
        c.transparent = transparent

        if !transparent {
            c.startMotion()
            let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan(_:)))
            v.addGestureRecognizer(pan)
        }

        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, SCNSceneRendererDelegate {

        var dbNode:      SCNNode?
        var ghostDb:     SCNNode?
        var freePlates:  [(node: SCNNode, def: FreePlateDef)]  = []
        var orbitPlates: [(node: SCNNode, def: OrbitDef)]      = []
        var transparent: Bool = false

        private let motion     = CMMotionManager()
        private var targetRotY: Float = 0.22
        private var targetRotX: Float = -0.08
        private var sceneStart: TimeInterval = 0
        private var isInteracting = false
        private var pendingDX: Float = 0
        private var pendingDY: Float = 0
        private var lastTranslation: CGPoint = .zero

        private let impactMed   = UIImpactFeedbackGenerator(style: .medium)
        private let impactLight = UIImpactFeedbackGenerator(style: .light)
        private let selection   = UISelectionFeedbackGenerator()

        override init() {
            super.init()
            impactMed.prepare(); impactLight.prepare(); selection.prepare()
        }

        func startMotion() {
            guard motion.isDeviceMotionAvailable else { return }
            motion.deviceMotionUpdateInterval = 1.0 / 60.0
            motion.startDeviceMotionUpdates()
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            if sceneStart == 0 { sceneStart = time }
            let t = Float(time - sceneStart)
            guard let db = dbNode else { return }

            if transparent {
                // Splash mode: smooth idle rotation only, no gyro, no float
                db.eulerAngles.y = t * 0.28   // ~one full turn per 22 s
            } else {
                if isInteracting {
                    db.eulerAngles.y += pendingDX
                    db.eulerAngles.x  = max(-0.65, min(0.65, db.eulerAngles.x + pendingDY))
                    pendingDX = 0; pendingDY = 0
                } else {
                    if let m = motion.deviceMotion {
                        let gx = Float(m.gravity.x)
                        let gy = Float(m.gravity.y + 0.6)
                        targetRotY = 0.22 + gx * 0.55
                        targetRotX = -0.08 + gy * 0.25
                    }
                    db.eulerAngles.x += (targetRotX - db.eulerAngles.x) * 0.04
                    db.eulerAngles.y += (targetRotY - db.eulerAngles.y) * 0.04
                }
            }

            if let ghost = ghostDb {
                ghost.eulerAngles = db.eulerAngles
                ghost.position    = db.position
            }

            for item in freePlates {
                let d = item.def
                item.node.eulerAngles.x += d.sx
                item.node.eulerAngles.y += d.sy
                item.node.eulerAngles.z += d.sz
                var p = item.node.position
                p.y = d.baseY + sin(t * 0.40 + d.phase) * 0.20
                p.x = d.baseX + cos(t * 0.30 + d.phase) * 0.12
                item.node.position = p
            }

            for item in orbitPlates {
                let d = item.def
                let angle = t * d.speed + d.phase
                let ex = cos(angle) * d.a
                let ey = sin(angle) * d.b
                item.node.position = SCNVector3(
                    ex * cos(d.tiltZ) - ey * sin(d.tiltX),
                    ex * sin(d.tiltZ) + ey * cos(d.tiltX),
                    d.zOff + sin(angle * 0.5) * 0.4
                )
                item.node.eulerAngles.x += 0.004
                item.node.eulerAngles.y += 0.003
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let db = dbNode else { return }
            let t = g.translation(in: g.view)
            let v = g.velocity(in: g.view)

            switch g.state {
            case .began:
                lastTranslation = t
                isInteracting   = true
                db.removeAction(forKey: "autoRotateY")
                db.removeAction(forKey: "floatAction")
                impactMed.impactOccurred()

            case .changed:
                let dx = Float(t.x - lastTranslation.x) * 0.013
                let dy = Float(t.y - lastTranslation.y) * 0.009
                lastTranslation = t
                pendingDX += dx; pendingDY += dy
                let speed = sqrt(v.x*v.x + v.y*v.y)
                if speed > 700 { impactLight.impactOccurred(intensity: CGFloat(min(speed/2000, 1))) }

            case .ended, .cancelled:
                isInteracting = false
                selection.selectionChanged()
                let vx          = Float(v.x)
                let flickAngle  = CGFloat(vx * 0.00008 * 60 * 1.4)
                let spin        = SCNAction.rotateBy(x: 0, y: flickAngle, z: 0, duration: 1.4)
                spin.timingMode = .easeOut
                db.runAction(spin) { self.resumeIdle(node: db) }

            default: break
            }
        }

        private func resumeIdle(node: SCNNode) {
            node.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat(Float.pi*2), z: 0, duration: 22)), forKey: "autoRotateY")
            let up = SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 2.8); up.timingMode = .easeInEaseOut
            let dn = SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 2.8); dn.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([up, dn])), forKey: "floatAction")
        }
    }

    // MARK: - Data structs

    struct FreePlateDef {
        let baseX, baseY, baseZ: Float
        let outerR: Float
        let sx, sy, sz: Float
        let phase: Float
    }

    struct OrbitDef {
        let a, b: Float
        let zOff: Float
        let tiltX, tiltZ: Float
        let speed, phase: Float
        let outerR: Float
    }

    struct SceneResult {
        let scene:       SCNScene
        let dbNode:      SCNNode
        let ghostDb:     SCNNode
        let freePlates:  [(node: SCNNode, def: FreePlateDef)]
        let orbitPlates: [(node: SCNNode, def: OrbitDef)]
    }

    // MARK: - Scene construction

    func buildScene(transparent: Bool, darkChrome: Bool = false) -> SceneResult {
        let scene = SCNScene()
        scene.background.contents = transparent ? UIColor.clear : UIColor.black

        if !transparent {
            scene.fogColor         = UIColor.black
            scene.fogStartDistance = 5.5
            scene.fogEndDistance   = 11.0
        }

        scene.lightingEnvironment.contents  = Self.makeEnvMap()
        scene.lightingEnvironment.intensity = darkChrome ? 0.6 : (transparent ? 2.4 : 1.8)

        // Camera — PerspectiveCamera(38) at (0, 0.3, 9)
        let cam = SCNNode(); cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 38
        cam.camera?.wantsHDR   = true
        cam.position           = SCNVector3(0, 0.3, 9)
        scene.rootNode.addChildNode(cam)

        // Lights — boosted for darkChrome so black metal gets visible shading against white bg
        let ambientInt:   CGFloat = darkChrome ? 200  : 500
        let keyInt:       CGFloat = darkChrome ? 2400 : 1800
        let rimInt:       CGFloat = darkChrome ? 900  : 750
        let fillInt:      CGFloat = darkChrome ? 600  : 950

        Self.addLight(scene, .ambient,     UIColor.white,                    ambientInt, .init(0,0,0))
        Self.addLight(scene, .directional, UIColor.white,                    keyInt,     .init(-0.95, -0.55, 0))
        Self.addLight(scene, .directional, UIColor(white:0.85, alpha:1),     rimInt,     .init( 0.55,  0.78, 0))

        let fillLight = SCNLight(); fillLight.type = .omni
        fillLight.intensity = fillInt; fillLight.color = UIColor.white
        fillLight.attenuationStartDistance = 4; fillLight.attenuationEndDistance = 28
        let fillNode = SCNNode(); fillNode.light = fillLight
        fillNode.position = SCNVector3(-5, 2, 5)
        scene.rootNode.addChildNode(fillNode)

        // ── PBR materials ──
        // darkChrome = light mode → near-black metal so it pops on white background
        // transparent (dark mode) → slightly grey so it's visible on black background
        // default (welcome screen) → full chrome white matching website
        let barMat: SCNMaterial
        let plateMat: SCNMaterial
        let plateDark: SCNMaterial
        let gripMat: SCNMaterial
        let edgeMat: SCNMaterial

        if darkChrome {
            // Low metalness → diffuse dark color dominates over reflections
            // This guarantees the dumbbell is visibly dark/black on a white background
            barMat    = Self.pbr(UIColor(white:0.08,alpha:1), 0.14, 0.62)
            plateMat  = Self.pbr(UIColor(white:0.10,alpha:1), 0.12, 0.68)
            plateDark = Self.pbr(UIColor(white:0.05,alpha:1), 0.10, 0.74)
            gripMat   = Self.pbr(UIColor(white:0.04,alpha:1), 0.04, 0.96)
            edgeMat   = Self.pbr(UIColor(white:0.20,alpha:1), 0.22, 0.44)
        } else if transparent {
            barMat    = Self.pbr(UIColor(white:0.68,alpha:1), 0.88, 0.12)
            plateMat  = Self.pbr(UIColor(white:0.65,alpha:1), 0.78, 0.22)
            plateDark = Self.pbr(UIColor(white:0.50,alpha:1), 0.68, 0.32)
            gripMat   = Self.pbr(UIColor(white:0.16,alpha:1), 0.05, 0.92)
            edgeMat   = Self.pbr(UIColor(white:0.78,alpha:1), 0.92, 0.08)
        } else {
            barMat    = Self.pbr(UIColor.white,                 0.92, 0.08)
            plateMat  = Self.pbr(UIColor(white:0.88,alpha:1),  0.80, 0.18)
            plateDark = Self.pbr(UIColor(white:0.69,alpha:1),  0.70, 0.28)
            gripMat   = Self.pbr(UIColor(white:0.16,alpha:1),  0.05, 0.92)
            edgeMat   = Self.pbr(UIColor.white,                 0.95, 0.05)
        }

        // ── Main dumbbell — geometry matching website 1:1 ──
        let db = SCNNode()
        db.eulerAngles = SCNVector3(-0.08, 0.22, -0.10)

        // Cylinder helper — rotated to lie along X axis (same as website cyl function)
        func cyl(_ r: Float, _ h: Float, _ m: SCNMaterial, _ x: Float) {
            let g = SCNCylinder(radius: CGFloat(r), height: CGFloat(h))
            g.radialSegmentCount = 48; g.materials = [m]
            let n = SCNNode(geometry: g)
            n.eulerAngles.z = Float.pi / 2
            n.position = SCNVector3(x, 0, 0)
            db.addChildNode(n)
        }

        // Torus helper — ring wrapping plate edge, oriented to face X axis
        func torus(_ r: Float, _ tube: Float, _ m: SCNMaterial, _ x: Float) {
            let g = SCNTorus(ringRadius: CGFloat(r), pipeRadius: CGFloat(tube))
            g.ringSegmentCount  = 80
            g.pipeSegmentCount  = 16
            g.materials         = [m]
            let n = SCNNode(geometry: g)
            n.eulerAngles.z = Float.pi / 2   // hole faces X axis
            n.position      = SCNVector3(x, 0, 0)
            db.addChildNode(n)
        }

        // Website: db.add(cyl(0.048,0.048,4.4,barMat,0))
        cyl(0.048, 4.4, barMat, 0)
        // Website: db.add(cyl(0.072,0.072,1.3,gripMat,0))
        cyl(0.072, 1.3, gripMat, 0)
        // Website: db.add(cyl(0.085,0.085,0.10,edgeMat, 0.71))
        cyl(0.085, 0.10, edgeMat,  0.71)
        cyl(0.085, 0.10, edgeMat, -0.71)

        // buildSide(1) and buildSide(-1) — exact match
        for s in [Float(1), Float(-1)] {
            // sleeve collar
            cyl(0.095, 0.14, edgeMat, s * 0.86)
            // main plate (front) — large stacked disc
            cyl(0.52,  0.13, plateMat,  s * 1.00)
            // torus ring around front plate edge
            torus(0.52, 0.013, edgeMat, s * 1.00)
            // main plate (back)
            cyl(0.52,  0.13, plateDark, s * 1.14)
            // smaller plate
            cyl(0.42,  0.10, plateMat,  s * 1.26)
            // even smaller
            cyl(0.32,  0.09, plateDark, s * 1.36)
            // end collar
            cyl(0.11,  0.18, edgeMat,   s * 1.46)
        }

        // Welcome screen animations (not for splash — handled in renderer loop)
        if !transparent {
            let up = SCNAction.moveBy(x:0,y:0.12,z:0,duration:2.8); up.timingMode = .easeInEaseOut
            let dn = SCNAction.moveBy(x:0,y:-0.12,z:0,duration:2.8); dn.timingMode = .easeInEaseOut
            db.runAction(.repeatForever(.sequence([up,dn])), forKey:"floatAction")
            db.runAction(.repeatForever(.rotateBy(x:0,y:CGFloat(Float.pi*2),z:0,duration:22)), forKey:"autoRotateY")
        }

        scene.rootNode.addChildNode(db)

        // ── Ghost wireframe overlay ──
        let ghostMat = SCNMaterial()
        ghostMat.fillMode         = .lines
        ghostMat.diffuse.contents = UIColor(white:1, alpha:0.032)
        ghostMat.lightingModel    = .constant
        ghostMat.isDoubleSided    = true

        let ghostDb = SCNNode()
        db.enumerateChildNodes { child, _ in
            guard let geo = child.geometry else { return }
            let copy = geo.copy() as! SCNGeometry; copy.materials = [ghostMat]
            let n = SCNNode(geometry: copy)
            n.position    = child.position
            n.eulerAngles = child.eulerAngles
            ghostDb.addChildNode(n)
        }
        ghostDb.scale = SCNVector3(1.018, 1.018, 1.018)
        scene.rootNode.addChildNode(ghostDb)

        // ── Floating plates + particles (dark scene only) ──
        var freeNodes:  [(node: SCNNode, def: FreePlateDef)]  = []
        var orbitNodes: [(node: SCNNode, def: OrbitDef)]      = []

        if !transparent {
            func discMat(_ depth: Float) -> SCNMaterial {
                let op = CGFloat(max(0.15, 0.58 - 0.36 * ((-depth - 3) / 4)))
                let m  = SCNMaterial()
                m.lightingModel    = .physicallyBased
                m.diffuse.contents = UIColor(white: 0.65, alpha: op)
                m.metalness.contents = CGFloat(0.72)
                m.roughness.contents = CGFloat(0.28)
                m.isDoubleSided    = true; m.blendMode = .alpha
                return m
            }
            func disc(_ r: Float, _ m: SCNMaterial) -> SCNGeometry {
                let g = SCNCylinder(radius: CGFloat(r), height: 0.065)
                g.radialSegmentCount = 52; g.materials = [m]; return g
            }

            let freeDefs: [FreePlateDef] = [
                .init(baseX:-4.2,baseY:1.8,baseZ:-3.5,outerR:0.40,sx:0.003,sy:0.009,sz:0.002,phase:0.0),
                .init(baseX:4.0,baseY:-1.4,baseZ:-5.0,outerR:0.56,sx:0.006,sy:0.003,sz:0.007,phase:1.3),
                .init(baseX:-2.6,baseY:-2.6,baseZ:-6.2,outerR:0.68,sx:0.004,sy:0.006,sz:0.003,phase:2.6),
            ]
            for d in freeDefs {
                let n = SCNNode(geometry: disc(d.outerR, discMat(d.baseZ)))
                n.position    = SCNVector3(d.baseX, d.baseY, d.baseZ)
                n.eulerAngles = SCNVector3(Float.random(in:0...Float.pi), Float.random(in:0...Float.pi), Float.random(in:0...Float.pi))
                scene.rootNode.addChildNode(n); freeNodes.append((n, d))
            }

            let orbitDefs: [OrbitDef] = [
                .init(a:4.2,b:2.0,zOff:-3.8,tiltX:0.38,tiltZ:0.15,speed:0.09,phase:0.0,outerR:0.34),
                .init(a:3.2,b:1.6,zOff:-4.8,tiltX:-0.28,tiltZ:0.30,speed:0.13,phase:2.1,outerR:0.46),
                .init(a:3.8,b:2.4,zOff:-5.5,tiltX:0.55,tiltZ:-0.20,speed:0.07,phase:4.2,outerR:0.30),
            ]
            for d in orbitDefs {
                let n = SCNNode(geometry: disc(d.outerR, discMat(d.zOff)))
                n.eulerAngles = SCNVector3(Float.random(in:0...Float.pi), Float.random(in:0...Float.pi), Float.random(in:0...Float.pi))
                scene.rootNode.addChildNode(n); orbitNodes.append((n, d))
            }

            // Particles
            let ps = SCNParticleSystem()
            ps.particleSize              = 0.015
            ps.particleColor             = UIColor(white:1, alpha:0.14)
            ps.particleColorVariation    = SCNVector4(0,0,0,0.06)
            ps.birthRate                 = 1
            ps.particleLifeSpan          = 9999
            ps.particleLifeSpanVariation = 0
            ps.emitterShape              = SCNBox(width:20, height:16, length:6, chamferRadius:0)
            ps.spreadingAngle            = 180
            ps.isLightingEnabled         = false
            ps.blendMode                 = .additive
            ps.particleVelocity          = 0
            ps.particleVelocityVariation = 0
            let pNode = SCNNode(); pNode.addParticleSystem(ps)
            pNode.runAction(.repeatForever(.rotateBy(x:0.018,y:0.018,z:0,duration:1)))
            scene.rootNode.addChildNode(pNode)
        }

        return SceneResult(scene:scene, dbNode:db, ghostDb:ghostDb, freePlates:freeNodes, orbitPlates:orbitNodes)
    }

    // MARK: - Helpers

    private static func addLight(_ scene: SCNScene, _ type: SCNLight.LightType,
                                  _ color: UIColor, _ intensity: CGFloat, _ euler: SCNVector3) {
        let n = SCNNode(); n.light = SCNLight()
        n.light!.type = type; n.light!.color = color
        n.light!.intensity = intensity; n.eulerAngles = euler
        scene.rootNode.addChildNode(n)
    }

    private static func pbr(_ color: UIColor, _ metalness: CGFloat, _ roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = metalness
        m.roughness.contents = roughness
        return m
    }

    /// Bright studio environment for dark chrome on white background
    private static func makeEnvMapBright() -> UIImage {
        let w = 256, h = 128
        return UIGraphicsImageRenderer(size: CGSize(width:w, height:h)).image { ctx in
            let gc = ctx.cgContext
            let cs = CGColorSpaceCreateDeviceRGB()
            gc.setFillColor(UIColor(white:0.78, alpha:1).cgColor)
            gc.fill(CGRect(x:0, y:0, width:w, height:h))
            let g1 = CGGradient(colorsSpace:cs,
                colors:[UIColor(white:1.0,alpha:1).cgColor, UIColor(white:0.78,alpha:0).cgColor] as CFArray,
                locations:[0,1])!
            gc.drawRadialGradient(g1,
                startCenter:.init(x:w/2, y:0), startRadius:0,
                endCenter:.init(x:w/2, y:0),   endRadius:CGFloat(h)*0.95, options:[])
            let g2 = CGGradient(colorsSpace:cs,
                colors:[UIColor(white:0.92,alpha:1).cgColor, UIColor(white:0.78,alpha:0).cgColor] as CFArray,
                locations:[0,1])!
            gc.drawRadialGradient(g2,
                startCenter:.init(x:0, y:CGFloat(h/2)), startRadius:0,
                endCenter:.init(x:0, y:CGFloat(h/2)),   endRadius:CGFloat(w)*0.5, options:[])
        }
    }

    /// Dark studio environment — gives chrome a silver/white tint on dark backgrounds
    private static func makeEnvMap() -> UIImage {
        let w = 256, h = 128
        return UIGraphicsImageRenderer(size: CGSize(width:w, height:h)).image { ctx in
            let gc = ctx.cgContext
            let cs = CGColorSpaceCreateDeviceRGB()
            gc.setFillColor(UIColor(white:0.04, alpha:1).cgColor)
            gc.fill(CGRect(x:0,y:0,width:w,height:h))
            let g1 = CGGradient(colorsSpace:cs,
                colors:[UIColor(white:0.28,alpha:1).cgColor, UIColor(white:0.04,alpha:1).cgColor] as CFArray,
                locations:[0,1])!
            gc.drawRadialGradient(g1,
                startCenter:.init(x:w/2,y:0), startRadius:0,
                endCenter:.init(x:w/2,y:0),   endRadius:CGFloat(h)*0.88, options:[])
            let g2 = CGGradient(colorsSpace:cs,
                colors:[UIColor(white:0.10,alpha:1).cgColor, UIColor(white:0.04,alpha:1).cgColor] as CFArray,
                locations:[0,1])!
            gc.drawRadialGradient(g2,
                startCenter:.init(x:0,y:CGFloat(h/2)), startRadius:0,
                endCenter:.init(x:0,y:CGFloat(h/2)),   endRadius:CGFloat(w)*0.42, options:[])
        }
    }
}
