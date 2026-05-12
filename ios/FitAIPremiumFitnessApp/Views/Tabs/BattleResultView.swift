import SwiftUI

struct BattleResultView: View {
    let battle: PhysiqueBattle
    let onDismiss: () -> Void

    @State private var showStamp: Bool = false
    @State private var stampScale: CGFloat = 3.0
    @State private var stampRotation: Double = -30
    @State private var stampOpacity: Double = 0
    @State private var showScores: Bool = false
    @State private var showShareCard: Bool = false

    private var muscleComparisons: [MuscleComparison] { battle.muscleComparisons }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                closeBar

                photosComparison

                if showScores {
                    if let verdict = battle.verdict, !verdict.isEmpty {
                        verdictBlock(verdict)
                    }

                    overallComparison

                    potentialComparison

                    if battle.biggestGap != nil || battle.closestCategory != nil {
                        biggestGapAndClosest
                    }

                    if muscleComparisons.count >= 3 {
                        radarChartSection
                    }

                    if !muscleComparisons.isEmpty {
                        muscleBreakdown
                    }

                    if !battle.player.strongPoints.isEmpty || !battle.opponent.strongPoints.isEmpty {
                        strengthsBlock
                    }

                    actionButtons
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                showStamp = true
                stampScale = 1.0
                stampOpacity = 1.0
                stampRotation = -12
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.2)) {
                showScores = true
            }
        }
        // fullScreenCover (not .sheet) because BattleResultView itself is
        // already presented as a fullScreenCover from BattleSetupView, and
        // SwiftUI .sheet nested inside .fullScreenCover auto-dismisses
        // when the parent's @Observable state mutates. The Close button
        // inside BattleShareSheet handles dismissal explicitly.
        .fullScreenCover(isPresented: $showShareCard) {
            BattleShareSheet(battle: battle)
        }
    }

    // MARK: - Close bar

    private var closeBar: some View {
        HStack {
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Photos comparison

    private var photosComparison: some View {
        VStack(spacing: 14) {
            Text("PHYSIQUE BATTLE")
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(3)
                .foregroundStyle(.red)

            GeometryReader { geo in
                let half = (geo.size.width - 2) / 2
                HStack(spacing: 0) {
                    photoTile(
                        photo: battle.player.photo,
                        name: battle.player.name,
                        score: battle.player.overallScore,
                        isWinner: battle.playerWins,
                        showMogged: !battle.playerWins && showStamp,
                        scoreAlignment: .leading,
                        half: half,
                        corners: RectangleCornerRadii(topLeading: 16, bottomLeading: 16, bottomTrailing: 0, topTrailing: 0)
                    )

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 280)

                    photoTile(
                        photo: battle.opponent.photo,
                        name: battle.opponent.name,
                        score: battle.opponent.overallScore,
                        isWinner: !battle.playerWins,
                        showMogged: battle.playerWins && showStamp,
                        scoreAlignment: .trailing,
                        half: half,
                        corners: RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 16, topTrailing: 16)
                    )
                }
            }
            .frame(height: 280)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text(winnerLine)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())

                if let tally = winTallyLine {
                    Text(tally)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func photoTile(
        photo: UIImage,
        name: String,
        score: Double,
        isWinner: Bool,
        showMogged: Bool,
        scoreAlignment: HorizontalAlignment,
        half: CGFloat,
        corners: RectangleCornerRadii
    ) -> some View {
        ZStack {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: half, height: 280)
                .clipped()
                .saturation(isWinner ? 1.0 : 0.4)
                .brightness(isWinner ? 0 : -0.05)

            if showMogged {
                moggedStamp
            }

            VStack {
                Spacer()
                HStack {
                    if scoreAlignment == .trailing { Spacer() }
                    VStack(alignment: scoreAlignment, spacing: 2) {
                        Text(name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(scoreText(score))
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundStyle(isWinner ? .green : .red)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(.rect(cornerRadius: 10))
                    if scoreAlignment == .leading { Spacer() }
                }
                .padding(8)
            }
        }
        .frame(width: half, height: 280)
        .clipShape(.rect(cornerRadii: corners))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: corners)
                .strokeBorder(isWinner ? Color.green.opacity(0.55) : Color.clear, lineWidth: 2)
        )
    }

    private var moggedStamp: some View {
        Text("MOGGED")
            .font(.system(size: 32, weight: .black, design: .rounded))
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.red, lineWidth: 3)
            )
            .rotationEffect(.degrees(stampRotation))
            .scaleEffect(stampScale)
            .opacity(stampOpacity)
    }

    // MARK: - AI verdict

    private func verdictBlock(_ verdict: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("AI VERDICT")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.purple)

                Text(verdict)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.18), lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Overall

    private var overallComparison: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Overall Score")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            comparisonRow(
                playerValue: battle.player.overallScore,
                opponentValue: battle.opponent.overallScore,
                playerLabel: battle.player.name,
                opponentLabel: battle.opponent.name
            )
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Potential

    private var potentialComparison: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Untapped Potential")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Genetic ceiling per AI")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            comparisonRow(
                playerValue: battle.player.potentialRating,
                opponentValue: battle.opponent.potentialRating,
                playerLabel: battle.player.name,
                opponentLabel: battle.opponent.name
            )
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Biggest gap / closest

    private var biggestGapAndClosest: some View {
        let sameCategory = battle.biggestGap?.id == battle.closestCategory?.id
        return HStack(spacing: 10) {
            if let gap = battle.biggestGap {
                gapChip(
                    icon: "hammer.fill",
                    title: "BIGGEST GAP",
                    label: gap.label,
                    diffText: "+\(scoreText(gap.difference))",
                    accent: .orange
                )
            }

            if let close = battle.closestCategory, !sameCategory {
                gapChip(
                    icon: "scope",
                    title: "CLOSEST",
                    label: close.label,
                    diffText: "+\(scoreText(close.difference))",
                    accent: .blue
                )
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func gapChip(icon: String, title: String, label: String, diffText: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(accent)
                HStack(spacing: 6) {
                    Text(label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(diffText)
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(accent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Radar chart

    private var radarChartSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Physique Fingerprint")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 10) {
                    legendDot(color: .green, label: shortName(battle.player.name))
                    legendDot(color: .red, label: shortName(battle.opponent.name))
                }
            }

            BattleRadarChart(
                labels: muscleComparisons.map(\.label),
                playerValues: muscleComparisons.map(\.playerScore),
                opponentValues: muscleComparisons.map(\.opponentScore),
                playerColor: .green,
                opponentColor: .red
            )
            .frame(height: 240)
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func shortName(_ name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return "—" }
        if n.count <= 10 { return n }
        return String(n.prefix(10)) + "…"
    }

    // MARK: - Muscle breakdown

    private var muscleBreakdown: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Muscle Breakdown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(categoryTallyLine)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.tertiary)
            }

            ForEach(muscleComparisons) { item in
                muscleRow(item)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func muscleRow(_ m: MuscleComparison) -> some View {
        let playerWinsRow = m.winner == .player
        let opponentWinsRow = m.winner == .opponent

        return VStack(spacing: 6) {
            HStack {
                Text(m.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    if playerWinsRow { winChip }
                    Text(scoreText(m.playerScore))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor(forWinner: playerWinsRow, tie: m.winner == .tie))
                }
                .frame(width: 54, alignment: .trailing)

                GeometryReader { geo in
                    let total = max(m.playerScore + m.opponentScore, 0.1)
                    let leftWidth = max(geo.size.width * (m.playerScore / total), 4)
                    let rightWidth = max(geo.size.width * (m.opponentScore / total), 4)
                    HStack(spacing: 2) {
                        Capsule()
                            .fill(barColor(forWinner: playerWinsRow, tie: m.winner == .tie))
                            .frame(width: leftWidth, height: 8)
                        Capsule()
                            .fill(barColor(forWinner: opponentWinsRow, tie: m.winner == .tie))
                            .frame(width: rightWidth, height: 8)
                    }
                }
                .frame(height: 8)

                HStack(spacing: 4) {
                    Text(scoreText(m.opponentScore))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor(forWinner: opponentWinsRow, tie: m.winner == .tie))
                    if opponentWinsRow { winChip }
                }
                .frame(width: 54, alignment: .leading)
            }
        }
    }

    private var winChip: some View {
        Text("W")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Color.green)
            .clipShape(Circle())
    }

    private func barColor(forWinner: Bool, tie: Bool) -> Color {
        if tie { return Color.gray.opacity(0.4) }
        return forWinner ? Color.green : Color.red.opacity(0.35)
    }

    private func scoreColor(forWinner: Bool, tie: Bool) -> Color {
        if tie { return .secondary }
        return forWinner ? .green : .red.opacity(0.7)
    }

    // MARK: - Strengths block

    private var strengthsBlock: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Where Each Shines")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                strengthColumn(name: battle.player.name, points: battle.player.strongPoints, color: .green)
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                strengthColumn(name: battle.opponent.name, points: battle.opponent.strongPoints, color: .red)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func strengthColumn(name: String, points: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(shortName(name))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if points.isEmpty {
                Text("No standout strengths")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(points.prefix(4), id: \.self) { point in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(color)
                        Text(point.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showShareCard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text("Share Battle Card")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(.rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: showShareCard)

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Shared comparison row

    private func comparisonRow(playerValue: Double, opponentValue: Double, playerLabel: String, opponentLabel: String) -> some View {
        let playerWinsRow = playerValue > opponentValue
        let tie = playerValue == opponentValue

        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(scoreText(playerValue))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(scoreColor(forWinner: playerWinsRow, tie: tie))
                    .frame(width: 32, alignment: .trailing)

                GeometryReader { geo in
                    let total = max(playerValue + opponentValue, 0.1)
                    let leftWidth = max(geo.size.width * (playerValue / total), 4)
                    let rightWidth = max(geo.size.width * (opponentValue / total), 4)
                    HStack(spacing: 2) {
                        Capsule()
                            .fill(barColor(forWinner: playerWinsRow, tie: tie))
                            .frame(width: leftWidth, height: 8)
                        Capsule()
                            .fill(barColor(forWinner: !playerWinsRow && !tie, tie: tie))
                            .frame(width: rightWidth, height: 8)
                    }
                }
                .frame(height: 8)

                Text(scoreText(opponentValue))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(scoreColor(forWinner: !playerWinsRow && !tie, tie: tie))
                    .frame(width: 32, alignment: .leading)
            }

            HStack {
                Text(playerLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer()
                Text(opponentLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Strings

    private var winnerLine: String {
        let pts = String(format: "%.1f", battle.scoreDifference)
        let name = battle.winner.name
        let isSelf = name.lowercased() == "you" || name.isEmpty
        return isSelf ? "You win by \(pts) points!" : "\(name) wins by \(pts) points!"
    }

    private var winTallyLine: String? {
        let total = muscleComparisons.count
        guard total > 0 else { return nil }
        let mine = battle.playerMuscleWins
        let theirs = battle.opponentMuscleWins
        if mine == theirs { return "Tied \(mine)–\(theirs) on muscle categories" }
        let isSelf = battle.winner.name.lowercased() == "you" || battle.winner.name.isEmpty
        let leadCount = max(mine, theirs)
        if mine > theirs {
            return isSelf
                ? "You took \(leadCount) of \(total) muscle categories"
                : "\(shortName(battle.player.name)) took \(leadCount) of \(total) categories"
        } else {
            return "\(shortName(battle.opponent.name)) took \(leadCount) of \(total) categories"
        }
    }

    private var categoryTallyLine: String {
        let tied = battle.tiedMuscles
        let base = "\(battle.playerMuscleWins)–\(battle.opponentMuscleWins)"
        return tied > 0 ? "\(base) · \(tied) tied" : base
    }

    private func scoreText(_ score: Double) -> String {
        "\(Int(round(score * 10)))"
    }
}

// MARK: - Radar chart

struct BattleRadarChart: View {
    let labels: [String]
    let playerValues: [Double]
    let opponentValues: [Double]
    let playerColor: Color
    let opponentColor: Color
    /// Scores are on a 0–10 scale; rings are drawn at quartiles.
    private let maxScore: Double = 10

    var body: some View {
        GeometryReader { geo in
            let labelPadding: CGFloat = 24
            let radius = min(geo.size.width, geo.size.height) / 2 - labelPadding
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let count = labels.count

            ZStack {
                // Grid rings (4 concentric polygons at 25/50/75/100% radius)
                ForEach(1...4, id: \.self) { ring in
                    PolygonShape(sides: count, radius: radius * CGFloat(ring) / 4, center: center)
                        .stroke(Color.primary.opacity(ring == 4 ? 0.18 : 0.08), lineWidth: 1)
                }

                // Spokes
                ForEach(0..<count, id: \.self) { i in
                    Path { path in
                        path.move(to: center)
                        let angle = Self.angle(for: i, total: count)
                        path.addLine(to: CGPoint(
                            x: center.x + radius * CGFloat(cos(angle)),
                            y: center.y + radius * CGFloat(sin(angle))
                        ))
                    }
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

                // Opponent polygon (drawn first so player polygon overlays)
                ScorePolygonShape(scores: opponentValues, maxScore: maxScore, radius: radius, center: center)
                    .fill(opponentColor.opacity(0.18))
                ScorePolygonShape(scores: opponentValues, maxScore: maxScore, radius: radius, center: center)
                    .stroke(opponentColor.opacity(0.8), lineWidth: 1.5)

                // Player polygon
                ScorePolygonShape(scores: playerValues, maxScore: maxScore, radius: radius, center: center)
                    .fill(playerColor.opacity(0.22))
                ScorePolygonShape(scores: playerValues, maxScore: maxScore, radius: radius, center: center)
                    .stroke(playerColor.opacity(0.9), lineWidth: 1.5)

                // Labels around the outer ring
                ForEach(0..<count, id: \.self) { i in
                    let angle = Self.angle(for: i, total: count)
                    let lr = radius + 14
                    Text(labels[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .position(
                            x: center.x + lr * CGFloat(cos(angle)),
                            y: center.y + lr * CGFloat(sin(angle))
                        )
                }
            }
        }
    }

    /// Place the first vertex at the top (12 o'clock), wind clockwise.
    private static func angle(for index: Int, total: Int) -> Double {
        -.pi / 2 + 2 * .pi * Double(index) / Double(max(total, 1))
    }
}

private struct PolygonShape: Shape {
    let sides: Int
    let radius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard sides >= 3 else { return path }
        for i in 0..<sides {
            let angle: Double = -.pi / 2 + 2 * .pi * Double(i) / Double(sides)
            let pt = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

private struct ScorePolygonShape: Shape {
    let scores: [Double]
    let maxScore: Double
    let radius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = scores.count
        guard count >= 3 else { return path }
        for i in 0..<count {
            let normalized = max(min(scores[i] / maxScore, 1), 0)
            let angle: Double = -.pi / 2 + 2 * .pi * Double(i) / Double(count)
            let r = radius * CGFloat(normalized)
            let pt = CGPoint(
                x: center.x + r * CGFloat(cos(angle)),
                y: center.y + r * CGFloat(sin(angle))
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
