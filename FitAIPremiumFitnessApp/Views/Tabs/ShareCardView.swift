import SwiftUI

struct ShareCardView: View {
    let result: ScanResult

    private var visibleScores: [(label: String, score: Double)] {
        let allScores: [(key: String, label: String, score: Double)] = [
            ("chest", "Chest", result.muscleScores.chest),
            ("shoulders", "Shoulders", result.muscleScores.shoulders),
            ("back", "Back", result.muscleScores.back),
            ("arms", "Arms", result.muscleScores.arms),
            ("legs", "Legs", result.muscleScores.legs),
            ("core", "Core", result.muscleScores.core),
        ]
        let visible = Set(result.visibleMuscleGroups.map { $0.lowercased() })
        return allScores
            .filter { visible.contains($0.key) && $0.score > 0 }
            .map { ($0.label, $0.score) }
    }

    private var gridItems: [[(label: String, score: Double)]] {
        var rows: [[(label: String, score: Double)]] = []
        let items = visibleScores
        var i = 0
        while i < items.count {
            if i + 1 < items.count {
                rows.append([items[i], items[i + 1]])
                i += 2
            } else {
                rows.append([items[i]])
                i += 1
            }
        }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                if let photo = result.frontPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                        )
                        .padding(.top, 24)
                }

                overallRow
                    .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    ForEach(Array(gridItems.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 16) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                                scoreCell(label: item.label, score: item.score)
                            }
                            if row.count == 1 {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Fit AI")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.03))
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var overallRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                Text(scoreText(result.overallScore))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                scoreBar(value: result.overallScore, color: barColor(result.overallScore))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Body Fat")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                Text(result.bodyFatEstimate)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                bodyFatBar()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scoreCell(label: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Text(scoreText(score))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            scoreBar(value: score, color: barColor(score))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyFatValue: Double {
        let numbers = result.bodyFatEstimate
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Double($0) }
        if numbers.count >= 2 {
            return (numbers[0] + numbers[1]) / 2.0
        } else if let first = numbers.first {
            return first
        }
        return 15
    }

    private func bodyFatBar() -> some View {
        let normalizedValue = min(max(bodyFatValue, 0), 40) / 40.0
        let color: Color = bodyFatValue <= 12 ? .green : bodyFatValue <= 20 ? Color(red: 0.85, green: 0.75, blue: 0.1) : .orange
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 5)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * normalizedValue), height: 5)
            }
        }
        .frame(height: 5)
    }

    private func scoreBar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 5)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * (value / 10)), height: 5)
            }
        }
        .frame(height: 5)
    }

    private func scoreText(_ score: Double) -> String {
        let scaled = Int(round(score * 10))
        return "\(scaled)"
    }

    private func barColor(_ score: Double) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return Color(red: 0.85, green: 0.75, blue: 0.1) }
        return .orange
    }
}

struct ShareCardRenderer {
    @MainActor
    static func render(result: ScanResult) -> UIImage? {
        let view = ShareCardView(result: result)
            .frame(width: 360)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
