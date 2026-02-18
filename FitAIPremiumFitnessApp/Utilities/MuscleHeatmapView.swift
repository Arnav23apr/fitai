import SwiftUI

struct MuscleHeatmapView: View {
    let strongPoints: [String]
    let weakPoints: [String]
    var compact: Bool = false

    private var strongMuscles: Set<String> { extractMuscles(from: strongPoints) }
    private var weakMuscles: Set<String> { extractMuscles(from: weakPoints) }

    private func muscleColor(_ muscle: String) -> Color {
        if weakMuscles.contains(muscle) { return .orange }
        if strongMuscles.contains(muscle) { return .green }
        return Color.white.opacity(0.1)
    }

    private func isHighlighted(_ muscle: String) -> Bool {
        weakMuscles.contains(muscle) || strongMuscles.contains(muscle)
    }

    var body: some View {
        VStack(spacing: compact ? 4 : 16) {
            HStack(spacing: compact ? 8 : 20) {
                singleBody(isFront: true)
                singleBody(isFront: false)
            }
            if !compact { legendRow }
        }
    }

    private func singleBody(isFront: Bool) -> some View {
        VStack(spacing: 4) {
            Canvas { ctx, size in
                drawBody(ctx: &ctx, size: size, isFront: isFront)
            }
            .frame(width: compact ? 60 : 120, height: compact ? 150 : 280)

            if !compact {
                Text(isFront ? "Front" : "Back")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Drawing

    private func drawBody(ctx: inout GraphicsContext, size: CGSize, isFront: Bool) {
        let refW: CGFloat = 120
        let refH: CGFloat = 280
        let s = min(size.width / refW, size.height / refH)
        let ox = (size.width - refW * s) / 2
        let oy = (size.height - refH * s) / 2

        func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: ox + (cx - rx) * s, y: oy + (cy - ry) * s,
                                   width: rx * 2 * s, height: ry * 2 * s))
        }

        func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
            Path(roundedRect: CGRect(x: ox + x * s, y: oy + y * s,
                                     width: w * s, height: h * s), cornerRadius: r * s)
        }

        func tri(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x3: CGFloat, _ y3: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: ox + x1 * s, y: oy + y1 * s))
            p.addLine(to: CGPoint(x: ox + x2 * s, y: oy + y2 * s))
            p.addLine(to: CGPoint(x: ox + x3 * s, y: oy + y3 * s))
            p.closeSubpath()
            return p
        }

        func fill(_ path: Path, _ muscle: String) {
            let color = muscleColor(muscle)
            if isHighlighted(muscle) {
                var g = ctx
                g.addFilter(.blur(radius: 4 * s))
                g.fill(path, with: .color(color.opacity(0.35)))
            }
            ctx.fill(path, with: .color(color))
            ctx.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 0.5 * s)
        }

        func neutral(_ path: Path) {
            ctx.fill(path, with: .color(Color.white.opacity(0.08)))
            ctx.stroke(path, with: .color(Color.white.opacity(0.1)), lineWidth: 0.4 * s)
        }

        neutral(ell(60, 16, 13, 15))
        neutral(rr(54, 30, 12, 8, 3))

        if isFront {
            drawFrontMuscles(ell: ell, rr: rr, tri: tri, fill: fill, neutral: neutral)
        } else {
            drawBackMuscles(ell: ell, rr: rr, tri: tri, fill: fill, neutral: neutral)
        }
    }

    private func drawFrontMuscles(
        ell: (CGFloat, CGFloat, CGFloat, CGFloat) -> Path,
        rr: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) -> Path,
        tri: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) -> Path,
        fill: (Path, String) -> Void,
        neutral: (Path) -> Void
    ) {
        fill(ell(42, 42, 8, 5), "traps")
        fill(ell(78, 42, 8, 5), "traps")

        fill(ell(26, 52, 12, 9), "shoulders")
        fill(ell(94, 52, 12, 9), "shoulders")

        fill(ell(44, 64, 14, 9), "chest")
        fill(ell(76, 64, 14, 9), "chest")

        fill(ell(18, 82, 7, 18), "biceps")
        fill(ell(102, 82, 7, 18), "biceps")

        fill(ell(14, 116, 5, 14), "forearms")
        fill(ell(106, 116, 5, 14), "forearms")

        fill(rr(46, 76, 28, 38, 5), "core")

        neutral(rr(38, 116, 44, 14, 5))

        fill(ell(47, 164, 12, 30), "quads")
        fill(ell(73, 164, 12, 30), "quads")

        fill(ell(45, 224, 9, 22), "calves")
        fill(ell(75, 224, 9, 22), "calves")

        neutral(rr(38, 248, 12, 6, 2))
        neutral(rr(70, 248, 12, 6, 2))

        neutral(rr(10, 130, 8, 10, 3))
        neutral(rr(102, 130, 8, 10, 3))
    }

    private func drawBackMuscles(
        ell: (CGFloat, CGFloat, CGFloat, CGFloat) -> Path,
        rr: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) -> Path,
        tri: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) -> Path,
        fill: (Path, String) -> Void,
        neutral: (Path) -> Void
    ) {
        fill(tri(54, 36, 32, 50, 50, 56), "traps")
        fill(tri(66, 36, 88, 50, 70, 56), "traps")

        fill(ell(26, 52, 12, 9), "shoulders")
        fill(ell(94, 52, 12, 9), "shoulders")

        fill(rr(36, 56, 20, 28, 5), "back")
        fill(rr(64, 56, 20, 28, 5), "back")
        fill(rr(42, 86, 36, 24, 5), "back")

        fill(ell(18, 82, 7, 18), "triceps")
        fill(ell(102, 82, 7, 18), "triceps")

        fill(ell(14, 116, 5, 14), "forearms")
        fill(ell(106, 116, 5, 14), "forearms")

        fill(ell(47, 130, 12, 11), "glutes")
        fill(ell(73, 130, 12, 11), "glutes")

        fill(ell(47, 170, 12, 30), "hamstrings")
        fill(ell(73, 170, 12, 30), "hamstrings")

        fill(ell(45, 226, 10, 24), "calves")
        fill(ell(75, 226, 10, 24), "calves")

        neutral(rr(38, 252, 12, 6, 2))
        neutral(rr(70, 252, 12, 6, 2))

        neutral(rr(10, 130, 8, 10, 3))
        neutral(rr(102, 130, 8, 10, 3))
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendDot(color: .green, text: "Strengths")
            legendDot(color: .orange, text: "Needs Work")
            legendDot(color: Color.white.opacity(0.12), text: "Neutral")
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
