import SwiftUI

struct ShareCardView: View {
    let result: ScanResult

    private var allScores: [(label: String, score: Double)] {
        let scores: [(key: String, label: String, score: Double)] = [
            ("chest", "Chest", result.muscleScores.chest),
            ("shoulders", "Shoulders", result.muscleScores.shoulders),
            ("back", "Back", result.muscleScores.back),
            ("arms", "Arms", result.muscleScores.arms),
            ("legs", "Legs", result.muscleScores.legs),
            ("core", "Core", result.muscleScores.core),
        ]
        return scores.filter { $0.score > 0 }.map { ($0.label, $0.score) }
    }

    private var gridRows: [[(label: String, score: Double)]] {
        var rows: [[(label: String, score: Double)]] = []
        var i = 0
        while i < allScores.count {
            if i + 1 < allScores.count {
                rows.append([allScores[i], allScores[i + 1]])
                i += 2
            } else {
                rows.append([allScores[i]])
                i += 1
            }
        }
        return rows
    }

    private let cardBg = Color(red: 0.07, green: 0.07, blue: 0.08)

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Ratings")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Photo
            if let photo = result.frontPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.green.opacity(0.7), .mint.opacity(0.5), .green.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .green.opacity(0.2), radius: 12, y: 4)
                    .padding(.bottom, 24)
            }

            // Scores card
            VStack(spacing: 18) {
                // Overall + Potential (top row, larger)
                HStack(spacing: 20) {
                    scoreCell(label: "Overall", score: result.overallScore, isLarge: true, customColor: nil)
                    scoreCell(label: "Potential", score: result.potentialRating, isLarge: true, customColor: potentialColor(result.potentialRating))
                }

                // Muscle scores grid
                ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 20) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                            scoreCell(label: item.label, score: item.score, isLarge: false, customColor: nil)
                        }
                        if row.count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)

            // Branding
            HStack(spacing: 6) {
                Image("FitAILogoWhite")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 18)
                    .opacity(0.35)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 360)
        .background(cardBg)
        .clipShape(.rect(cornerRadius: 22))
    }

    // MARK: - Score Cell

    private func scoreCell(label: String, score: Double, isLarge: Bool, customColor: Color?) -> some View {
        let scaled = Int(round(score * 10))
        let color = customColor ?? barColor(score)

        return VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: isLarge ? 14 : 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            Text("\(scaled)")
                .font(.system(size: isLarge ? 44 : 36, weight: .bold, design: .rounded))
                .foregroundStyle(customColor != nil ? color : .white)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * (score / 10)), height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Colors

    private func potentialColor(_ score: Double) -> Color {
        if score >= 8 { return .cyan }
        if score >= 6 { return .green }
        return Color(red: 0.85, green: 0.75, blue: 0.1)
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
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
