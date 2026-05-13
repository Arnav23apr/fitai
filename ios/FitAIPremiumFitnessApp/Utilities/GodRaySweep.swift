import SwiftUI

/// One-shot god-ray light sweep. Fires when `active` flips true: a
/// bright radial bloom expands from `origin` across the parent's
/// bounds in ~450ms, then fades. Stack-up of two layers:
///   1. A soft RadialGradient core that bleaches whatever's
///      underneath via `.plusLighter` blending.
///   2. An AngularGradient fan of 8 alternating bright/clear spokes,
///      rotated and masked to a growing circle, that gives the bloom
///      directional "ray" structure rather than a flat circle.
///
/// Used on PhysiqueRewardView when each stat counts up — pairs with
/// the count-up animation so finishing the roll feels like the data
/// is *radiating* the win, not just appearing.
struct GodRaySweepModifier: ViewModifier {
    /// Flip false → true to fire one pass.
    var active: Bool
    /// Total duration in seconds.
    var duration: Double = 0.55
    /// Where the bloom emanates from, in unit-coordinate space.
    var origin: UnitPoint = .leading

    @State private var startDate: Date? = nil

    func body(content: Content) -> some View {
        content
            .overlay {
                if let start = startDate {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                        sweep(elapsed: ctx.date.timeIntervalSince(start))
                    }
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: active) { _, on in
                guard on else { return }
                startDate = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
                    startDate = nil
                }
            }
    }

    @ViewBuilder
    private func sweep(elapsed: TimeInterval) -> some View {
        let progress = min(elapsed / duration, 1.0)
        // Ease-out scale (slow at the end) so the bloom feels like
        // it's settling rather than rocketing off-screen.
        let scaleEase = 1 - pow(1 - progress, 2.5)
        // Opacity peaks early then fades to zero by the end.
        let opacity = max(0, 1.0 - pow(progress, 1.5))

        GeometryReader { geo in
            let center = CGPoint(
                x: origin.x * geo.size.width,
                y: origin.y * geo.size.height
            )
            let maxDim = max(geo.size.width, geo.size.height) * 1.6
            let diameter = maxDim * scaleEase

            ZStack {
                // Layer 1 — soft bleach core. RadialGradient with a
                // strong white center decaying to clear gives the
                // bloom its luminous body.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.65),
                                .white.opacity(0.18),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter * 0.5
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .position(center)
                    .blendMode(.plusLighter)

                // Layer 2 — directional rays. 8 alternating bright/
                // clear spokes via an AngularGradient, masked to the
                // bloom circle, rotated as it grows for a "fanning"
                // motion. Lower opacity than the core so the spokes
                // read as accents, not stripes.
                AngularGradient(
                    stops: rayStops(),
                    center: .center,
                    angle: .degrees(progress * 18)
                )
                .frame(width: diameter, height: diameter)
                .mask(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.55),
                                    .white.opacity(0.12),
                                    .clear,
                                ],
                                center: .center,
                                startRadius: diameter * 0.05,
                                endRadius: diameter * 0.5
                            )
                        )
                )
                .position(center)
                .blendMode(.plusLighter)
                .opacity(0.55)
            }
            .opacity(opacity)
            .compositingGroup()
        }
    }

    /// Eight alternating bright/clear stops around the circle so the
    /// AngularGradient reads as discrete light shafts radiating out.
    private func rayStops() -> [Gradient.Stop] {
        let count = 8
        var stops: [Gradient.Stop] = []
        for i in 0..<count {
            let pos = Double(i) / Double(count)
            stops.append(.init(color: .white.opacity(0.85), location: pos))
            stops.append(.init(color: .clear, location: pos + 0.5 / Double(count)))
        }
        return stops
    }
}

extension View {
    /// One-shot radiating god-ray bloom. Flip `active` true to fire.
    /// Returns to idle automatically after `duration` elapses.
    func godRaySweep(
        active: Bool,
        duration: Double = 0.55,
        origin: UnitPoint = .leading
    ) -> some View {
        modifier(GodRaySweepModifier(active: active, duration: duration, origin: origin))
    }
}
