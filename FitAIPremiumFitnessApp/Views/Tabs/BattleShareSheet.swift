import SwiftUI

struct BattleShareSheet: View {
    let battle: PhysiqueBattle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    BattleShareCardView(battle: battle)
                        .padding(.horizontal, 16)

                    Button {
                        renderAndShare()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.black)
            .navigationTitle("Share Battle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    @MainActor
    private func renderAndShare() {
        let card = BattleShareCardView(battle: battle)
            .frame(width: 400)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topVC = root
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

struct BattleShareCardView: View {
    let battle: PhysiqueBattle

    private var sharedVisibleGroups: [(key: String, label: String)] {
        let allMuscles: [(key: String, label: String)] = [
            ("chest", "Chest"), ("shoulders", "Shoulders"), ("back", "Back"),
            ("arms", "Arms"), ("legs", "Legs"), ("core", "Core")
        ]
        let pSet = Set(battle.player.visibleMuscleGroups.map { $0.lowercased() })
        let oSet = Set(battle.opponent.visibleMuscleGroups.map { $0.lowercased() })
        let visible = pSet.union(oSet)
        return allMuscles.filter { visible.contains($0.key) }
    }

    private var gridRows: [[(key: String, label: String)]] {
        var rows: [[(key: String, label: String)]] = []
        let items = sharedVisibleGroups
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
            Text("PHYSIQUE BATTLE")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(.red)
                .padding(.top, 20)
                .padding(.bottom, 6)

            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                Text("\(battle.winner.name) wins by \(String(format: "%.1f", battle.scoreDifference))!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 16)

            HStack(spacing: 10) {
                contestantCard(
                    contestant: battle.player,
                    isWinner: battle.playerWins,
                    isMogged: !battle.playerWins
                )

                Text("VS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.red)

                contestantCard(
                    contestant: battle.opponent,
                    isWinner: !battle.playerWins,
                    isMogged: battle.playerWins
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                Text("Fit AI")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.02))
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.07))
        .clipShape(.rect(cornerRadius: 22))
    }

    private func contestantCard(contestant: BattleContestant, isWinner: Bool, isMogged: Bool) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Image(uiImage: contestant.photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isWinner
                                    ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [.red.opacity(0.5), .red.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2.5
                            )
                    )

                if isMogged {
                    Text("MOGGED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(.red, lineWidth: 1.5)
                        )
                        .clipShape(.rect(cornerRadius: 3))
                        .rotationEffect(.degrees(-12))
                        .offset(y: 20)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, isMogged ? 14 : 8)

            Text(contestant.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)

            Text(overallText(contestant.overallScore))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(isWinner ? .green : .white)
                .padding(.top, 2)

            scoreBar(value: contestant.overallScore, isWinner: isWinner)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 14)

            VStack(spacing: 10) {
                ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, muscle in
                            let score = scoreForMuscle(muscle.key, scores: contestant.muscleScores)
                            miniScoreCell(label: muscle.label, score: score, isWinner: isWinner)
                        }
                        if row.count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isWinner ? Color.green.opacity(0.15) : Color.white.opacity(0.04),
                    lineWidth: 1
                )
        )
    }

    private func miniScoreCell(label: String, score: Double, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text(scoreText(score))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            miniBar(value: score, isWinner: isWinner)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniBar(value: Double, isWinner: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 4)
                Capsule()
                    .fill(barColor(value, isWinner: isWinner))
                    .frame(width: max(0, geo.size.width * (value / 10)), height: 4)
            }
        }
        .frame(height: 4)
    }

    private func scoreBar(value: Double, isWinner: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 5)
                Capsule()
                    .fill(isWinner ? Color.green : Color.white.opacity(0.25))
                    .frame(width: max(0, geo.size.width * (value / 10)), height: 5)
            }
        }
        .frame(height: 5)
    }

    private func barColor(_ score: Double, isWinner: Bool) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return Color(red: 0.85, green: 0.75, blue: 0.1) }
        return .orange
    }

    private func overallText(_ score: Double) -> String {
        "\(Int(round(score * 10)))"
    }

    private func scoreText(_ score: Double) -> String {
        "\(Int(round(score * 10)))"
    }

    private func scoreForMuscle(_ key: String, scores: MuscleScores) -> Double {
        switch key {
        case "chest": return scores.chest
        case "shoulders": return scores.shoulders
        case "back": return scores.back
        case "arms": return scores.arms
        case "legs": return scores.legs
        case "core": return scores.core
        default: return 0
        }
    }
}
