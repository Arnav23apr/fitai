import SwiftUI
import SceneKit

/// Drop-in "stardust" particle layer behind premium-feel screens. Wraps
/// SceneKit's `SCNParticleSystem` in a transparent `SCNView` so it
/// composites over whatever's below.
///
/// Keep it sparse. The effect is atmosphere, not a snow globe — every
/// premium AI/fitness paywall in the corpus (Cal AI, Symmetry, Pingo)
/// uses a particle field at low density. Cranking it up reads as a
/// screensaver, not as polish.
///
/// Defaults are tuned to mirror the welcome screen's drift but slightly
/// denser, and to pre-warm so the cloud appears fully-formed on first
/// frame rather than fading in over a minute.
struct ParticleBackgroundView: UIViewRepresentable {
    /// Particle color including alpha. Default is soft warm-white.
    var tint: UIColor = UIColor(white: 1, alpha: 0.30)
    /// Birth-rate multiplier. 1.0 = ~6 particles/sec emerging, with a
    /// ~40s lifespan giving ~240 active particles at any moment.
    var density: CGFloat = 1.0
    /// Cloud rotation speed in radians per second on X and Y. 0.05 is a
    /// gentle but visible drift. Bump to 0.1 for a noticeable current.
    var driftSpeed: CGFloat = 0.05
    /// Particle size in SceneKit world units. 0.04 reads as fine dust on
    /// a 2D backdrop; 0.08 reads as snow.
    var particleSize: CGFloat = 0.04

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.autoenablesDefaultLighting = false
        v.isUserInteractionEnabled = false  // pass-through taps to overlaid SwiftUI
        v.scene = buildScene()
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Camera positioned close to the emitter volume so particles
        // fill more screen real estate. Moving it from z=8 to z=5 makes
        // particles ~60% larger on screen for the same particleSize.
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 200
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(camNode)

        let ps = SCNParticleSystem()
        ps.particleSize = particleSize
        ps.particleColor = tint
        ps.particleColorVariation = SCNVector4(0, 0, 0, 0.10)
        ps.birthRate = 6 * density
        // warmupDuration advances the simulation N seconds before the
        // first render frame, so the cloud is fully populated on appear
        // rather than fading in over the lifespan window.
        ps.warmupDuration = 12
        ps.particleLifeSpan = 40
        ps.particleLifeSpanVariation = 20
        ps.emitterShape = SCNBox(width: 18, height: 14, length: 6, chamferRadius: 0)
        ps.spreadingAngle = 180
        ps.isLightingEnabled = false
        // Additive blending is what gives the particles the soft glow
        // look — overlapping particles brighten the pixel rather than
        // darkening it. Without this they read as flat dots.
        ps.blendMode = .additive
        ps.particleVelocity = 0
        ps.particleVelocityVariation = 0

        let pNode = SCNNode()
        pNode.addParticleSystem(ps)
        pNode.runAction(.repeatForever(
            .rotateBy(x: driftSpeed, y: driftSpeed, z: 0, duration: 1)
        ))
        scene.rootNode.addChildNode(pNode)

        return scene
    }
}
