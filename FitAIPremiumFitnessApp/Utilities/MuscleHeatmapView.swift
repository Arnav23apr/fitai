import SwiftUI

struct MuscleHeatmapView: View {
    let strongPoints: [String]
    let weakPoints: [String]
    var compact: Bool = false

    private var strongMuscles: Set<String> { extractMuscles(from: strongPoints) }
    private var weakMuscles: Set<String> { extractMuscles(from: weakPoints) }

    var body: some View {
        VStack(spacing: compact ? 4 : 14) {
            HStack(spacing: compact ? 14 : 32) {
                BodyFigureCanvas(
                    strongMuscles: strongMuscles,
                    weakMuscles: weakMuscles,
                    isFront: true,
                    compact: compact
                )
                BodyFigureCanvas(
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
            legendDot(color: Color(red: 0.93, green: 0.47, blue: 0.56), text: "Strengths")
            legendDot(color: Color(red: 1.0, green: 0.78, blue: 0.12), text: "Needs Work")
            legendDot(color: Color(white: 0.82), text: "Neutral")
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
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

private struct BodyFigureCanvas: View {
    let strongMuscles: Set<String>
    let weakMuscles: Set<String>
    let isFront: Bool
    var compact: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var baseColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.82)
    }

    private let strongColor = Color(red: 0.93, green: 0.35, blue: 0.45)
    private let weakColor = Color(red: 1.0, green: 0.72, blue: 0.18)

    nonisolated private struct Region {
        let muscle: String
        let cx: CGFloat
        let cy: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    nonisolated private struct BodyPart {
        let cx: CGFloat
        let cy: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    private static let silhouette: [BodyPart] = [
        BodyPart(cx: 0.50, cy: 0.060, w: 0.20, h: 0.080),
        BodyPart(cx: 0.50, cy: 0.115, w: 0.10, h: 0.030),
        BodyPart(cx: 0.50, cy: 0.165, w: 0.50, h: 0.055),
        BodyPart(cx: 0.50, cy: 0.240, w: 0.40, h: 0.110),
        BodyPart(cx: 0.50, cy: 0.330, w: 0.34, h: 0.070),
        BodyPart(cx: 0.50, cy: 0.390, w: 0.38, h: 0.055),
        BodyPart(cx: 0.20, cy: 0.235, w: 0.090, h: 0.130),
        BodyPart(cx: 0.80, cy: 0.235, w: 0.090, h: 0.130),
        BodyPart(cx: 0.16, cy: 0.365, w: 0.070, h: 0.110),
        BodyPart(cx: 0.84, cy: 0.365, w: 0.070, h: 0.110),
        BodyPart(cx: 0.14, cy: 0.450, w: 0.050, h: 0.035),
        BodyPart(cx: 0.86, cy: 0.450, w: 0.050, h: 0.035),
        BodyPart(cx: 0.40, cy: 0.520, w: 0.155, h: 0.185),
        BodyPart(cx: 0.60, cy: 0.520, w: 0.155, h: 0.185),
        BodyPart(cx: 0.39, cy: 0.730, w: 0.115, h: 0.165),
        BodyPart(cx: 0.61, cy: 0.730, w: 0.115, h: 0.165),
        BodyPart(cx: 0.38, cy: 0.870, w: 0.095, h: 0.040),
        BodyPart(cx: 0.62, cy: 0.870, w: 0.095, h: 0.040),
    ]

    private static let frontMuscles: [Region] = [
        Region(muscle: "chest", cx: 0.42, cy: 0.210, w: 0.15, h: 0.060),
        Region(muscle: "chest", cx: 0.58, cy: 0.210, w: 0.15, h: 0.060),
        Region(muscle: "shoulders", cx: 0.27, cy: 0.168, w: 0.12, h: 0.042),
        Region(muscle: "shoulders", cx: 0.73, cy: 0.168, w: 0.12, h: 0.042),
        Region(muscle: "biceps", cx: 0.20, cy: 0.240, w: 0.070, h: 0.100),
        Region(muscle: "biceps", cx: 0.80, cy: 0.240, w: 0.070, h: 0.100),
        Region(muscle: "forearms", cx: 0.16, cy: 0.365, w: 0.055, h: 0.085),
        Region(muscle: "forearms", cx: 0.84, cy: 0.365, w: 0.055, h: 0.085),
        Region(muscle: "core", cx: 0.50, cy: 0.310, w: 0.18, h: 0.095),
        Region(muscle: "quads", cx: 0.40, cy: 0.520, w: 0.125, h: 0.155),
        Region(muscle: "quads", cx: 0.60, cy: 0.520, w: 0.125, h: 0.155),
    ]

    private static let backMuscles: [Region] = [
        Region(muscle: "traps", cx: 0.50, cy: 0.145, w: 0.24, h: 0.050),
        Region(muscle: "shoulders", cx: 0.27, cy: 0.168, w: 0.12, h: 0.042),
        Region(muscle: "shoulders", cx: 0.73, cy: 0.168, w: 0.12, h: 0.042),
        Region(muscle: "back", cx: 0.50, cy: 0.255, w: 0.32, h: 0.115),
        Region(muscle: "triceps", cx: 0.20, cy: 0.255, w: 0.070, h: 0.090),
        Region(muscle: "triceps", cx: 0.80, cy: 0.255, w: 0.070, h: 0.090),
        Region(muscle: "glutes", cx: 0.44, cy: 0.410, w: 0.13, h: 0.060),
        Region(muscle: "glutes", cx: 0.56, cy: 0.410, w: 0.13, h: 0.060),
        Region(muscle: "hamstrings", cx: 0.40, cy: 0.545, w: 0.125, h: 0.140),
        Region(muscle: "hamstrings", cx: 0.60, cy: 0.545, w: 0.125, h: 0.140),
        Region(muscle: "calves", cx: 0.39, cy: 0.740, w: 0.090, h: 0.120),
        Region(muscle: "calves", cx: 0.61, cy: 0.740, w: 0.090, h: 0.120),
    ]

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let w = size.width
                let h = size.height

                for part in Self.silhouette {
                    let rect = CGRect(
                        x: (part.cx - part.w / 2) * w,
                        y: (part.cy - part.h / 2) * h,
                        width: part.w * w,
                        height: part.h * h
                    )
                    context.fill(Capsule().path(in: rect), with: .color(baseColor))
                }

                let regions = isFront ? Self.frontMuscles : Self.backMuscles
                for region in regions {
                    let color: Color
                    if strongMuscles.contains(region.muscle) {
                        color = strongColor
                    } else if weakMuscles.contains(region.muscle) {
                        color = weakColor
                    } else {
                        continue
                    }

                    let glowRect = CGRect(
                        x: (region.cx - region.w * 0.7) * w,
                        y: (region.cy - region.h * 0.7) * h,
                        width: region.w * 1.4 * w,
                        height: region.h * 1.4 * h
                    )
                    context.fill(Ellipse().path(in: glowRect), with: .color(color.opacity(0.2)))

                    let rect = CGRect(
                        x: (region.cx - region.w / 2) * w,
                        y: (region.cy - region.h / 2) * h,
                        width: region.w * w,
                        height: region.h * h
                    )
                    context.fill(Ellipse().path(in: rect), with: .color(color.opacity(0.8)))
                }
            }
            .aspectRatio(0.45, contentMode: .fit)
            .frame(height: compact ? 170 : 280)

            if !compact {
                Text(isFront ? "Front" : "Back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
