import SwiftUI

struct MuscleHeatmapView: View {
    let strongPoints: [String]
    let weakPoints: [String]
    var compact: Bool = false

    private var strongMuscles: Set<String> { extractMuscles(from: strongPoints) }
    private var weakMuscles: Set<String> { extractMuscles(from: weakPoints) }

    private let strongColor = Color(red: 0.9, green: 0.12, blue: 0.12)
    private let weakColor = Color(red: 1.0, green: 0.78, blue: 0.12)
    private let neutralColor = Color(white: 0.35)

    private struct MuscleAsset {
        let muscle: String
        let assetName: String
    }

    private let frontAssets: [MuscleAsset] = [
        MuscleAsset(muscle: "chest", assetName: "MuscleChestFront"),
        MuscleAsset(muscle: "shoulders", assetName: "MuscleShouldersFront"),
        MuscleAsset(muscle: "biceps", assetName: "MuscleBicepsFront"),
        MuscleAsset(muscle: "forearms", assetName: "MuscleforearmsFront"),
        MuscleAsset(muscle: "core", assetName: "MuscleCoreFront"),
        MuscleAsset(muscle: "quads", assetName: "MuscleQuadsFront"),
    ]

    private let backAssets: [MuscleAsset] = [
        MuscleAsset(muscle: "shoulders", assetName: "MuscleShouldersBack"),
        MuscleAsset(muscle: "traps", assetName: "MuscleTrapsBack"),
        MuscleAsset(muscle: "back", assetName: "MuscleBackBack"),
        MuscleAsset(muscle: "glutes", assetName: "MuscleGlutesBack"),
        MuscleAsset(muscle: "calves", assetName: "MuscleCalvesBack"),
    ]

    private var activeFrontAssets: [MuscleAsset] {
        let all = strongMuscles.union(weakMuscles)
        return frontAssets.filter { all.contains($0.muscle) }
    }

    private var activeBackAssets: [MuscleAsset] {
        let all = strongMuscles.union(weakMuscles)
        var assets = backAssets.filter { all.contains($0.muscle) }
        if all.contains("triceps") {
            if let shoulderAsset = backAssets.first(where: { $0.muscle == "shoulders" }),
               !assets.contains(where: { $0.muscle == "shoulders" }) {
                assets.append(shoulderAsset)
            }
        }
        if all.contains("hamstrings") {
            if let gluteAsset = backAssets.first(where: { $0.muscle == "glutes" }),
               !assets.contains(where: { $0.muscle == "glutes" }) {
                assets.append(gluteAsset)
            }
        }
        return assets
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
        let assets = isFront ? activeFrontAssets : activeBackAssets
        let baseAsset = isFront ? "MuscleChestFront" : "MuscleBackBack"
        let figHeight: CGFloat = compact ? 170 : 280

        return VStack(spacing: 6) {
            ZStack {
                Image(assets.isEmpty ? baseAsset : assets[0].assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                if assets.count > 1 {
                    ForEach(1..<assets.count, id: \.self) { i in
                        Image(assets[i].assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blendMode(.darken)
                    }
                }
            }
            .frame(height: figHeight)
            .clipShape(.rect(cornerRadius: compact ? 4 : 8))

            if !compact {
                Text(isFront ? "Front" : "Back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
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
