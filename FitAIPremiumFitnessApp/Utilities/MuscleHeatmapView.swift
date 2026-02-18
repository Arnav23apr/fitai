import SwiftUI

struct MuscleHeatmapView: View {
    let strongPoints: [String]
    let weakPoints: [String]
    var compact: Bool = false

    private var strongMuscles: Set<String> { extractMuscles(from: strongPoints) }
    private var weakMuscles: Set<String> { extractMuscles(from: weakPoints) }

    private let strongColor = Color(red: 1.0, green: 0.35, blue: 0.48)
    private let weakColor = Color(red: 1.0, green: 0.78, blue: 0.22)

    var body: some View {
        VStack(spacing: compact ? 4 : 14) {
            HStack(spacing: compact ? 14 : 32) {
                BodyFigureView(
                    strongMuscles: strongMuscles,
                    weakMuscles: weakMuscles,
                    isFront: true,
                    compact: compact
                )
                BodyFigureView(
                    strongMuscles: strongMuscles,
                    weakMuscles: weakMuscles,
                    isFront: false,
                    compact: compact
                )
            }
            if !compact { legendRow }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendDot(color: strongColor, text: "Strengths")
            legendDot(color: weakColor, text: "Needs Work")
            legendDot(color: Color(white: 0.55), text: "Neutral")
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func extractMuscles(from points: [String]) -> Set<String> {
        var muscles = Set<String>()
        for point in points {
            let l = point.lowercased()
            if l.contains("chest") || l.contains("pec") { muscles.insert("chest") }
            if l.contains("shoulder") || l.contains("delt") { muscles.insert("shoulders") }
            if l.contains("back") || l.contains("lat") || l.contains("rhomboid") || l.contains("v-taper") || l.contains("v taper") { muscles.insert("back") }
            if l.contains("bicep") { muscles.insert("biceps") }
            if l.contains("tricep") { muscles.insert("triceps") }
            if l.contains("arm") && !l.contains("forearm") { muscles.formUnion(["biceps", "triceps"]) }
            if l.contains("forearm") { muscles.insert("forearms") }
            if l.contains("core") || l.contains("ab") || l.contains("midsection") || l.contains("oblique") { muscles.insert("core") }
            if l.contains("quad") || l.contains("thigh") { muscles.insert("quads") }
            if l.contains("hamstring") { muscles.insert("hamstrings") }
            if l.contains("leg") { muscles.formUnion(["quads", "hamstrings", "calves"]) }
            if l.contains("glute") || l.contains("hip") { muscles.insert("glutes") }
            if l.contains("calf") || l.contains("calves") { muscles.insert("calves") }
            if l.contains("trap") || l.contains("neck") { muscles.insert("traps") }
            if l.contains("upper body") { muscles.formUnion(["chest", "shoulders", "back", "biceps", "triceps"]) }
            if l.contains("lower body") { muscles.formUnion(["quads", "hamstrings", "glutes", "calves"]) }
            if l.contains("symmetry") || l.contains("posture") { muscles.formUnion(["back", "glutes", "hamstrings"]) }
            if l.contains("lean") { muscles.insert("core") }
        }
        return muscles
    }
}

private struct BodyFigureView: View {
    let strongMuscles: Set<String>
    let weakMuscles: Set<String>
    let isFront: Bool
    var compact: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private let strongColor = Color(red: 1.0, green: 0.35, blue: 0.48)
    private let weakColor = Color(red: 1.0, green: 0.78, blue: 0.22)

    private var baseColor: Color {
        colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.78)
    }

    nonisolated private struct BodyPart {
        let cx: CGFloat
        let cy: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    nonisolated private struct MuscleRegion {
        let muscle: String
        let cx: CGFloat
        let cy: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    private static let silhouette: [BodyPart] = [
        BodyPart(cx: 0.50, cy: 0.058, w: 0.19, h: 0.078),
        BodyPart(cx: 0.50, cy: 0.112, w: 0.09, h: 0.028),
        BodyPart(cx: 0.50, cy: 0.162, w: 0.48, h: 0.052),
        BodyPart(cx: 0.50, cy: 0.235, w: 0.38, h: 0.105),
        BodyPart(cx: 0.50, cy: 0.325, w: 0.32, h: 0.065),
        BodyPart(cx: 0.50, cy: 0.385, w: 0.36, h: 0.050),
        BodyPart(cx: 0.21, cy: 0.230, w: 0.085, h: 0.125),
        BodyPart(cx: 0.79, cy: 0.230, w: 0.085, h: 0.125),
        BodyPart(cx: 0.17, cy: 0.360, w: 0.065, h: 0.105),
        BodyPart(cx: 0.83, cy: 0.360, w: 0.065, h: 0.105),
        BodyPart(cx: 0.15, cy: 0.445, w: 0.045, h: 0.032),
        BodyPart(cx: 0.85, cy: 0.445, w: 0.045, h: 0.032),
        BodyPart(cx: 0.41, cy: 0.515, w: 0.150, h: 0.180),
        BodyPart(cx: 0.59, cy: 0.515, w: 0.150, h: 0.180),
        BodyPart(cx: 0.40, cy: 0.725, w: 0.110, h: 0.160),
        BodyPart(cx: 0.60, cy: 0.725, w: 0.110, h: 0.160),
        BodyPart(cx: 0.39, cy: 0.865, w: 0.090, h: 0.038),
        BodyPart(cx: 0.61, cy: 0.865, w: 0.090, h: 0.038),
    ]

    private static let frontMuscles: [MuscleRegion] = [
        MuscleRegion(muscle: "chest", cx: 0.42, cy: 0.205, w: 0.15, h: 0.058),
        MuscleRegion(muscle: "chest", cx: 0.58, cy: 0.205, w: 0.15, h: 0.058),
        MuscleRegion(muscle: "shoulders", cx: 0.28, cy: 0.165, w: 0.11, h: 0.040),
        MuscleRegion(muscle: "shoulders", cx: 0.72, cy: 0.165, w: 0.11, h: 0.040),
        MuscleRegion(muscle: "biceps", cx: 0.21, cy: 0.235, w: 0.065, h: 0.095),
        MuscleRegion(muscle: "biceps", cx: 0.79, cy: 0.235, w: 0.065, h: 0.095),
        MuscleRegion(muscle: "forearms", cx: 0.17, cy: 0.360, w: 0.050, h: 0.080),
        MuscleRegion(muscle: "forearms", cx: 0.83, cy: 0.360, w: 0.050, h: 0.080),
        MuscleRegion(muscle: "core", cx: 0.50, cy: 0.305, w: 0.17, h: 0.090),
        MuscleRegion(muscle: "quads", cx: 0.41, cy: 0.515, w: 0.120, h: 0.150),
        MuscleRegion(muscle: "quads", cx: 0.59, cy: 0.515, w: 0.120, h: 0.150),
    ]

    private static let backMuscles: [MuscleRegion] = [
        MuscleRegion(muscle: "traps", cx: 0.50, cy: 0.142, w: 0.22, h: 0.048),
        MuscleRegion(muscle: "shoulders", cx: 0.28, cy: 0.165, w: 0.11, h: 0.040),
        MuscleRegion(muscle: "shoulders", cx: 0.72, cy: 0.165, w: 0.11, h: 0.040),
        MuscleRegion(muscle: "back", cx: 0.50, cy: 0.250, w: 0.30, h: 0.110),
        MuscleRegion(muscle: "triceps", cx: 0.21, cy: 0.250, w: 0.065, h: 0.085),
        MuscleRegion(muscle: "triceps", cx: 0.79, cy: 0.250, w: 0.065, h: 0.085),
        MuscleRegion(muscle: "glutes", cx: 0.44, cy: 0.405, w: 0.12, h: 0.055),
        MuscleRegion(muscle: "glutes", cx: 0.56, cy: 0.405, w: 0.12, h: 0.055),
        MuscleRegion(muscle: "hamstrings", cx: 0.41, cy: 0.540, w: 0.120, h: 0.135),
        MuscleRegion(muscle: "hamstrings", cx: 0.59, cy: 0.540, w: 0.120, h: 0.135),
        MuscleRegion(muscle: "calves", cx: 0.40, cy: 0.735, w: 0.085, h: 0.115),
        MuscleRegion(muscle: "calves", cx: 0.60, cy: 0.735, w: 0.085, h: 0.115),
    ]

    private let figureHeight: CGFloat = 280
    private let compactHeight: CGFloat = 170

    private var height: CGFloat { compact ? compactHeight : figureHeight }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    Canvas { context, size in
                        for part in Self.silhouette {
                            let rect = CGRect(
                                x: (part.cx - part.w / 2) * size.width,
                                y: (part.cy - part.h / 2) * size.height,
                                width: part.w * size.width,
                                height: part.h * size.height
                            )
                            context.fill(Capsule().path(in: rect), with: .color(baseColor))
                        }
                    }

                    let regions = isFront ? Self.frontMuscles : Self.backMuscles
                    ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                        if let color = colorFor(region.muscle) {
                            heatSpot(
                                cx: region.cx, cy: region.cy,
                                rw: region.w, rh: region.h,
                                color: color, containerW: w, containerH: h
                            )
                        }
                    }
                }
            }
            .aspectRatio(0.45, contentMode: .fit)
            .frame(height: height)
            .clipped()

            if !compact {
                Text(isFront ? "Front" : "Back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func colorFor(_ muscle: String) -> Color? {
        if strongMuscles.contains(muscle) { return strongColor }
        if weakMuscles.contains(muscle) { return weakColor }
        return nil
    }

    private func heatSpot(cx: CGFloat, cy: CGFloat, rw: CGFloat, rh: CGFloat, color: Color, containerW: CGFloat, containerH: CGFloat) -> some View {
        let blurAmount: CGFloat = compact ? 6 : 10
        let outerScale: CGFloat = 1.8
        let innerScale: CGFloat = 1.0

        let posX = cx * containerW
        let posY = cy * containerH
        let spotW = rw * containerW
        let spotH = rh * containerH

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.35), color.opacity(0.12), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(spotW, spotH) * outerScale * 0.5
                    )
                )
                .frame(width: spotW * outerScale, height: spotH * outerScale)
                .blur(radius: blurAmount * 1.2)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.55), color.opacity(0.25), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(spotW, spotH) * 0.5
                    )
                )
                .frame(width: spotW * innerScale * 1.3, height: spotH * innerScale * 1.3)
                .blur(radius: blurAmount * 0.6)

            Ellipse()
                .fill(color.opacity(0.6))
                .frame(width: spotW * 0.6, height: spotH * 0.6)
                .blur(radius: blurAmount * 0.3)
        }
        .position(x: posX, y: posY)
        .allowsHitTesting(false)
    }
}
