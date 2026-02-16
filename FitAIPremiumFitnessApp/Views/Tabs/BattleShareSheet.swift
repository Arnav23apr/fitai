import SwiftUI

struct BattleShareSheet: View {
    let battle: PhysiqueBattle
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    BattleShareCardView(battle: battle)
                        .padding(.horizontal, 20)

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
                    .padding(.horizontal, 20)
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
            .frame(width: 380)
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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("PHYSIQUE BATTLE")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .tracking(3)
                    .foregroundStyle(.red)
                    .padding(.top, 20)

                HStack(spacing: 0) {
                    ZStack {
                        Image(uiImage: battle.player.photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .clipped()

                        if !battle.playerWins {
                            moggedStamp
                        }

                        VStack {
                            Spacer()
                            HStack {
                                nameTag(name: battle.player.name, score: battle.player.overallScore, isWinner: battle.playerWins, alignment: .leading)
                                Spacer()
                            }
                            .padding(6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadii: .init(topLeading: 12, bottomLeading: 12)))

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)

                    ZStack {
                        Image(uiImage: battle.opponent.photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .clipped()

                        if battle.playerWins {
                            moggedStamp
                        }

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                nameTag(name: battle.opponent.name, score: battle.opponent.overallScore, isWinner: !battle.playerWins, alignment: .trailing)
                            }
                            .padding(6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadii: .init(bottomTrailing: 12, topTrailing: 12)))
                }
                .frame(height: 220)
                .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text("\(battle.winner.name) wins!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())

                VStack(spacing: 8) {
                    ForEach(sharedVisibleGroups, id: \.key) { muscle in
                        shareComparisonRow(
                            label: muscle.label,
                            leftScore: scoreForMuscle(muscle.key, scores: battle.player.muscleScores),
                            rightScore: scoreForMuscle(muscle.key, scores: battle.opponent.muscleScores)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Fit AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var moggedStamp: some View {
        Text("MOGGED")
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.red, lineWidth: 2.5)
            )
            .rotationEffect(.degrees(-12))
    }

    private func nameTag(name: String, score: Double, isWinner: Bool, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
            Text("\(Int(round(score * 10)))")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(isWinner ? .green : .red)
        }
        .padding(6)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func shareComparisonRow(label: String, leftScore: Double, rightScore: Double) -> some View {
        HStack(spacing: 8) {
            Text("\(Int(round(leftScore * 10)))")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(leftScore >= rightScore ? .green : .white.opacity(0.4))
                .frame(width: 28, alignment: .trailing)

            GeometryReader { geo in
                let total = max(leftScore + rightScore, 0.1)
                let leftW = max(geo.size.width * (leftScore / total), 3)
                let rightW = max(geo.size.width * (rightScore / total), 3)

                HStack(spacing: 1) {
                    Capsule()
                        .fill(leftScore >= rightScore ? Color.green.opacity(0.7) : Color.white.opacity(0.1))
                        .frame(width: leftW, height: 6)
                    Capsule()
                        .fill(rightScore > leftScore ? Color.red.opacity(0.7) : Color.white.opacity(0.1))
                        .frame(width: rightW, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(Int(round(rightScore * 10)))")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(rightScore > leftScore ? .red : .white.opacity(0.4))
                .frame(width: 28, alignment: .leading)
        }
        .overlay(
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        )
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
