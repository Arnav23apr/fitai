import SwiftUI

struct BattleShareSheet: View {
    let battle: PhysiqueBattle
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private var lang: String { appState.profile.selectedLanguage }

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
                            Text(L.t("share", lang))
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
            .background(Color(.systemBackground))
            .navigationTitle(L.t("shareBattleTitle", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("close", lang)) { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @MainActor
    private func renderAndShare() {
        let card = BattleShareCardView(battle: battle)
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

    private let cardBg = Color(red: 0.07, green: 0.07, blue: 0.08)

    private var sharedVisibleGroups: [(key: String, label: String)] {
        let allMuscles: [(key: String, label: String)] = [
            ("chest", "Chest"), ("shoulders", "Shoulders"), ("back", "Back"),
            ("arms", "Arms"), ("legs", "Legs"), ("glutes", "Glutes"), ("core", "Core")
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

    /// Headline copy under the title. Switches to a tie message
    /// when the battle ended in a draw.
    private var headlineCopy: String {
        if battle.isTie {
            let pts = String(format: "%.1f", battle.player.overallScore)
            return "Tied at \(pts) points!"
        }
        let diff = String(format: "%.1f", battle.scoreDifference)
        return "\(battle.winner.name) wins by \(diff)!"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Physique Battle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 24)
                .padding(.bottom, 6)

            HStack(spacing: 6) {
                Image(systemName: battle.isTie ? "equal.circle.fill" : "crown.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text(headlineCopy)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.bottom, 20)

            HStack(alignment: .top, spacing: 12) {
                contestantBlock(
                    contestant: battle.player,
                    isWinner: battle.playerWins,
                    isMogged: battle.outcome == .opponent
                )

                Text(battle.isTie ? "DRAW" : "VS")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(battle.isTie ? Color.yellow.opacity(0.85) : .white.opacity(0.35))
                    .padding(.top, 70)

                contestantBlock(
                    contestant: battle.opponent,
                    isWinner: battle.outcome == .opponent,
                    isMogged: battle.playerWins
                )
            }
            .padding(.horizontal, 16)

            Image("FitAILogoWhite")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 18)
                .opacity(0.35)
                .padding(.top, 20)
                .padding(.bottom, 24)
        }
        .frame(width: 380)
        .background(cardBg)
        .clipShape(.rect(cornerRadius: 22))
    }

    private func contestantBlock(contestant: BattleContestant, isWinner: Bool, isMogged: Bool) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Image(uiImage: contestant.photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isWinner
                                    ? LinearGradient(
                                        colors: [.green.opacity(0.7), .mint.opacity(0.5), .green.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [.red.opacity(0.5), .red.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: isWinner ? .green.opacity(0.2) : .clear, radius: 12, y: 4)

                if isMogged {
                    Text("MOGGED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(.red, lineWidth: 1.5)
                        )
                        .clipShape(.rect(cornerRadius: 3))
                        .rotationEffect(.degrees(-12))
                        .offset(y: 26)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, isMogged ? 18 : 12)

            Text(contestant.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .padding(.bottom, 14)

            VStack(spacing: 16) {
                scoreCell(
                    label: "Overall",
                    score: contestant.overallScore,
                    isLarge: true,
                    customColor: isWinner ? .green : nil
                )

                ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 14) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, muscle in
                            let score = scoreForMuscle(muscle.key, scores: contestant.muscleScores)
                            scoreCell(label: muscle.label, score: score, isLarge: false, customColor: nil)
                        }
                        if row.count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isWinner ? Color.green.opacity(0.15) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreCell(label: String, score: Double, isLarge: Bool, customColor: Color?) -> some View {
        let scaled = Int(round(score * 10))
        let color = customColor ?? barColor(score)

        return VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: isLarge ? 12 : 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            Text("\(scaled)")
                .font(.system(size: isLarge ? 32 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(customColor != nil ? color : .white)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: isLarge ? 5 : 4)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * (score / 10)), height: isLarge ? 5 : 4)
                }
            }
            .frame(height: isLarge ? 5 : 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barColor(_ score: Double) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return Color(red: 0.85, green: 0.75, blue: 0.1) }
        return .orange
    }

    private func scoreForMuscle(_ key: String, scores: MuscleScores) -> Double {
        switch key {
        case "chest": return scores.chest
        case "shoulders": return scores.shoulders
        case "back": return scores.back
        case "arms": return scores.arms
        case "legs": return scores.legs
        case "core": return scores.core
        case "glutes": return scores.glutes
        default: return 0
        }
    }
}
