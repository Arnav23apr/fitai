import SwiftUI

struct MuscleHeatmapView: View {
    let strongPoints: [String]
    let weakPoints: [String]
    var compact: Bool = false

    private var strongMuscles: Set<String> { extractMuscles(from: strongPoints) }
    private var weakMuscles: Set<String> { extractMuscles(from: weakPoints) }

    private let bodyFill = Color(white: 0.18)
    private let bodyOutline = Color(white: 0.35)
    private let strongColor = Color(red: 0.9, green: 0.12, blue: 0.12)
    private let weakColor = Color(red: 1.0, green: 0.78, blue: 0.12)

    private func muscleColor(_ muscle: String) -> Color {
        if strongMuscles.contains(muscle) { return strongColor }
        if weakMuscles.contains(muscle) { return weakColor }
        return .clear
    }

    private func isActive(_ muscle: String) -> Bool {
        strongMuscles.contains(muscle) || weakMuscles.contains(muscle)
    }

    var body: some View {
        VStack(spacing: compact ? 4 : 14) {
            HStack(spacing: compact ? 14 : 32) {
                bodyFigure(isFront: true)
                bodyFigure(isFront: false)
            }
            if !compact { legendRow }
        }
    }

    private func bodyFigure(isFront: Bool) -> some View {
        VStack(spacing: 6) {
            Canvas { ctx, size in
                let rW: CGFloat = 140
                let rH: CGFloat = 340
                let sc = min(size.width / rW, size.height / rH)
                let ox = (size.width - rW * sc) / 2
                let oy = (size.height - rH * sc) / 2

                let t = Transform(sc: sc, ox: ox, oy: oy)

                drawSilhouette(ctx: &ctx, t: t)
                if isFront {
                    drawFrontMuscles(ctx: &ctx, t: t)
                } else {
                    drawBackMuscles(ctx: &ctx, t: t)
                }
                drawSilhouetteOutline(ctx: &ctx, t: t)
            }
            .frame(width: compact ? 70 : 140, height: compact ? 170 : 340)

            if !compact {
                Text(isFront ? "Front" : "Back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct Transform {
        let sc: CGFloat
        let ox: CGFloat
        let oy: CGFloat
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * sc, y: oy + y * sc)
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: ox + x * sc, y: oy + y * sc, width: w * sc, height: h * sc)
        }
        var lw: CGFloat { 0.7 * sc }
    }

    // MARK: - Silhouette

    private func drawSilhouette(ctx: inout GraphicsContext, t: Transform) {
        let c = bodyFill

        ctx.fill(Path(ellipseIn: t.r(56, 1, 28, 32)), with: .color(c))
        ctx.fill(Path(roundedRect: t.r(63, 30, 14, 18), cornerRadius: 4 * t.sc), with: .color(c))

        var torso = Path()
        torso.move(to: t.p(22, 46))
        torso.addCurve(to: t.p(38, 128), control1: t.p(20, 72), control2: t.p(28, 104))
        torso.addCurve(to: t.p(34, 162), control1: t.p(34, 140), control2: t.p(32, 154))
        torso.addLine(to: t.p(54, 180))
        torso.addLine(to: t.p(86, 180))
        torso.addCurve(to: t.p(102, 128), control1: t.p(108, 154), control2: t.p(106, 140))
        torso.addCurve(to: t.p(118, 46), control1: t.p(112, 104), control2: t.p(120, 72))
        torso.closeSubpath()
        ctx.fill(torso, with: .color(c))

        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(22, 46), (10, 68), (6, 98)],
                 inner: [(24, 98), (30, 72), (36, 52)])
        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(118, 46), (130, 68), (134, 98)],
                 inner: [(116, 98), (110, 72), (104, 52)])

        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(6, 96), (2, 124), (0, 150)],
                 inner: [(16, 150), (20, 124), (24, 96)])
        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(134, 96), (138, 124), (140, 150)],
                 inner: [(124, 150), (120, 124), (116, 96)])

        ctx.fill(Path(ellipseIn: t.r(-4, 146, 20, 20)), with: .color(c))
        ctx.fill(Path(ellipseIn: t.r(124, 146, 20, 20)), with: .color(c))

        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(36, 172), (34, 210), (34, 248)],
                 inner: [(64, 248), (66, 210), (66, 172)])
        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(74, 172), (74, 210), (76, 248)],
                 inner: [(106, 248), (106, 210), (104, 172)])

        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(36, 250), (34, 282), (38, 320)],
                 inner: [(60, 320), (62, 282), (62, 250)])
        fillLimb(ctx: &ctx, t: t, c: c,
                 outer: [(78, 250), (78, 282), (80, 320)],
                 inner: [(102, 320), (106, 282), (104, 250)])

        ctx.fill(Path(ellipseIn: t.r(30, 316, 28, 14)), with: .color(c))
        ctx.fill(Path(ellipseIn: t.r(82, 316, 28, 14)), with: .color(c))
    }

    private func fillLimb(ctx: inout GraphicsContext, t: Transform, c: Color, outer: [(CGFloat, CGFloat)], inner: [(CGFloat, CGFloat)]) {
        var path = Path()
        guard outer.count >= 2 && inner.count >= 2 else { return }
        path.move(to: t.p(outer[0].0, outer[0].1))
        for i in 1..<outer.count {
            let prev = outer[i - 1]
            let curr = outer[i]
            let cx = (prev.0 + curr.0) / 2
            let cy = (prev.1 + curr.1) / 2
            path.addQuadCurve(to: t.p(curr.0, curr.1), control: t.p(cx + (curr.0 - prev.0) * 0.2, cy))
        }
        path.addLine(to: t.p(inner[0].0, inner[0].1))
        for i in 1..<inner.count {
            let prev = inner[i - 1]
            let curr = inner[i]
            let cx = (prev.0 + curr.0) / 2
            let cy = (prev.1 + curr.1) / 2
            path.addQuadCurve(to: t.p(curr.0, curr.1), control: t.p(cx + (curr.0 - prev.0) * 0.2, cy))
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(c))
    }

    // MARK: - Outline

    private func drawSilhouetteOutline(ctx: inout GraphicsContext, t: Transform) {
        let c = bodyOutline
        let lw = t.lw
        ctx.stroke(Path(ellipseIn: t.r(56, 1, 28, 32)), with: .color(c), lineWidth: lw)
    }

    // MARK: - Front Muscles

    private func drawFrontMuscles(ctx: inout GraphicsContext, t: Transform) {
        muscle(ctx: &ctx, t: t, name: "shoulders", pts: [
            (22, 46), (14, 54), (8, 68), (12, 82), (22, 80), (30, 68), (36, 52)
        ])
        muscle(ctx: &ctx, t: t, name: "shoulders", pts: [
            (118, 46), (126, 54), (132, 68), (128, 82), (118, 80), (110, 68), (104, 52)
        ])

        muscle(ctx: &ctx, t: t, name: "chest", pts: [
            (36, 52), (38, 48), (66, 50), (68, 66), (64, 82), (44, 88), (36, 76)
        ])
        muscle(ctx: &ctx, t: t, name: "chest", pts: [
            (104, 52), (102, 48), (74, 50), (72, 66), (76, 82), (96, 88), (104, 76)
        ])

        muscle(ctx: &ctx, t: t, name: "biceps", pts: [
            (18, 62), (12, 74), (8, 92), (10, 98), (22, 98), (26, 82), (24, 66)
        ])
        muscle(ctx: &ctx, t: t, name: "biceps", pts: [
            (122, 62), (128, 74), (132, 92), (130, 98), (118, 98), (114, 82), (116, 66)
        ])

        muscle(ctx: &ctx, t: t, name: "forearms", pts: [
            (8, 98), (4, 118), (2, 140), (0, 150), (16, 150), (18, 140), (22, 118), (24, 98)
        ])
        muscle(ctx: &ctx, t: t, name: "forearms", pts: [
            (132, 98), (136, 118), (138, 140), (140, 150), (124, 150), (122, 140), (118, 118), (116, 98)
        ])

        muscle(ctx: &ctx, t: t, name: "core", pts: [
            (48, 84), (92, 84), (94, 120), (92, 152), (86, 164), (54, 164), (48, 152), (46, 120)
        ])

        muscle(ctx: &ctx, t: t, name: "quads", pts: [
            (38, 174), (36, 200), (34, 228), (36, 246), (62, 246), (64, 228), (66, 200), (64, 174)
        ])
        muscle(ctx: &ctx, t: t, name: "quads", pts: [
            (76, 174), (76, 200), (76, 228), (78, 246), (104, 246), (106, 228), (104, 200), (102, 174)
        ])

        muscle(ctx: &ctx, t: t, name: "calves", pts: [
            (38, 254), (36, 274), (36, 296), (40, 316), (58, 316), (60, 296), (62, 274), (60, 254)
        ])
        muscle(ctx: &ctx, t: t, name: "calves", pts: [
            (80, 254), (80, 274), (80, 296), (82, 316), (100, 316), (102, 296), (104, 274), (102, 254)
        ])
    }

    // MARK: - Back Muscles

    private func drawBackMuscles(ctx: inout GraphicsContext, t: Transform) {
        muscle(ctx: &ctx, t: t, name: "traps", pts: [
            (70, 36), (46, 48), (36, 64), (40, 80), (56, 86), (70, 88), (84, 86), (100, 80), (104, 64), (94, 48)
        ])

        muscle(ctx: &ctx, t: t, name: "shoulders", pts: [
            (22, 46), (14, 54), (8, 68), (12, 82), (22, 80), (30, 68), (36, 52)
        ])
        muscle(ctx: &ctx, t: t, name: "shoulders", pts: [
            (118, 46), (126, 54), (132, 68), (128, 82), (118, 80), (110, 68), (104, 52)
        ])

        muscle(ctx: &ctx, t: t, name: "back", pts: [
            (38, 58), (34, 78), (34, 100), (38, 118), (48, 130), (66, 134), (70, 134),
            (74, 134), (92, 130), (102, 118), (106, 100), (106, 78), (102, 58)
        ])

        muscle(ctx: &ctx, t: t, name: "triceps", pts: [
            (18, 62), (12, 74), (8, 92), (10, 98), (22, 98), (26, 82), (24, 66)
        ])
        muscle(ctx: &ctx, t: t, name: "triceps", pts: [
            (122, 62), (128, 74), (132, 92), (130, 98), (118, 98), (114, 82), (116, 66)
        ])

        muscle(ctx: &ctx, t: t, name: "forearms", pts: [
            (8, 98), (4, 118), (2, 140), (0, 150), (16, 150), (18, 140), (22, 118), (24, 98)
        ])
        muscle(ctx: &ctx, t: t, name: "forearms", pts: [
            (132, 98), (136, 118), (138, 140), (140, 150), (124, 150), (122, 140), (118, 118), (116, 98)
        ])

        muscle(ctx: &ctx, t: t, name: "back", pts: [
            (44, 130), (42, 148), (48, 162), (70, 166), (92, 162), (98, 148), (96, 130)
        ])

        muscle(ctx: &ctx, t: t, name: "glutes", pts: [
            (38, 154), (36, 164), (40, 176), (56, 180), (66, 176), (66, 162), (56, 154)
        ])
        muscle(ctx: &ctx, t: t, name: "glutes", pts: [
            (102, 154), (104, 164), (100, 176), (84, 180), (74, 176), (74, 162), (84, 154)
        ])

        muscle(ctx: &ctx, t: t, name: "hamstrings", pts: [
            (38, 180), (36, 206), (34, 232), (36, 246), (62, 246), (64, 232), (66, 206), (64, 180)
        ])
        muscle(ctx: &ctx, t: t, name: "hamstrings", pts: [
            (76, 180), (76, 206), (76, 232), (78, 246), (104, 246), (106, 232), (106, 206), (102, 180)
        ])

        muscle(ctx: &ctx, t: t, name: "calves", pts: [
            (38, 252), (34, 270), (34, 292), (40, 316), (58, 316), (60, 292), (62, 270), (60, 252)
        ])
        muscle(ctx: &ctx, t: t, name: "calves", pts: [
            (80, 252), (80, 270), (80, 292), (82, 316), (100, 316), (104, 292), (106, 270), (102, 252)
        ])
    }

    // MARK: - Muscle Drawing

    private func muscle(ctx: inout GraphicsContext, t: Transform, name: String, pts: [(CGFloat, CGFloat)]) {
        let points = pts.map { t.p($0.0, $0.1) }
        let path = smoothClosedPath(points)

        if isActive(name) {
            let color = muscleColor(name)
            var glow = ctx
            glow.addFilter(.blur(radius: 4 * t.sc))
            glow.fill(path, with: .color(color.opacity(0.35)))
            ctx.fill(path, with: .color(color))
        }
        ctx.stroke(path, with: .color(bodyOutline), lineWidth: t.lw)
    }

    private func smoothClosedPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        let n = points.count
        guard n >= 3 else {
            if n > 0 {
                path.move(to: points[0])
                for i in 1..<n { path.addLine(to: points[i]) }
                path.closeSubpath()
            }
            return path
        }

        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendDot(color: strongColor, text: "Strengths")
            legendDot(color: weakColor, text: "Needs Work")
            legendDot(color: bodyFill, text: "Neutral")
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Extraction

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
