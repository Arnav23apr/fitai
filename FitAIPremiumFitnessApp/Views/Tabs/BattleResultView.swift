import SwiftUI

struct BattleResultView: View {
    @Environment(AppState.self) private var appState
    let battle: PhysiqueBattle
    let onDismiss: () -> Void

    private var lang: String { appState.profile.selectedLanguage }

    @State private var showStamp: Bool = false
    @State private var stampScale: CGFloat = 3.0
    @State private var stampRotation: Double = -30
    @State private var stampOpacity: Double = 0
    @State private var showScores: Bool = false
    @State private var showShareCard: Bool = false

    private var sharedVisibleGroups: [String] {
        let pSet = Set(battle.player.visibleMuscleGroups.map { $0.lowercased() })
        let oSet = Set(battle.opponent.visibleMuscleGroups.map { $0.lowercased() })
        return Array(pSet.union(oSet)).sorted()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                closeBar

                photosComparison

                if showScores {
                    overallComparison

                    muscleComparison

                    actionButtons
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.black)
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
        .sheet(isPresented: $showShareCard) {
            BattleShareSheet(battle: battle)
        }
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var photosComparison: some View {
        VStack(spacing: 16) {
            Text(L.t("physiqueBattleHeader", lang))
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(3)
                .foregroundStyle(.red)

            HStack(spacing: 0) {
                ZStack {
                    Image(uiImage: battle.player.photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 280)
                        .clipped()

                    if !battle.playerWins && showStamp {
                        moggedStamp
                    }

                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(battle.player.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(scoreText(battle.player.overallScore))
                                    .font(.system(.title, design: .rounded, weight: .black))
                                    .foregroundStyle(battle.playerWins ? .green : .red)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial.opacity(0.9))
                            .clipShape(.rect(cornerRadius: 10))
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, bottomLeading: 16)))

                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)

                ZStack {
                    Image(uiImage: battle.opponent.photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 280)
                        .clipped()

                    if battle.playerWins && showStamp {
                        moggedStamp
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(battle.opponent.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(scoreText(battle.opponent.overallScore))
                                    .font(.system(.title, design: .rounded, weight: .black))
                                    .foregroundStyle(!battle.playerWins ? .green : .red)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial.opacity(0.9))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadii: .init(bottomTrailing: 16, topTrailing: 16)))
            }
            .frame(height: 280)

            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                Text(L.t("winsBy", lang).replacingOccurrences(of: "%@", with: battle.winner.name).replacingOccurrences(of: "%@", with: String(format: "%.1f", battle.scoreDifference)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
        }
    }

    private var moggedStamp: some View {
        Text(L.t("moggedStamp", lang))
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

    private var overallComparison: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("overallScoreLabel", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            comparisonBar(
                leftValue: battle.player.overallScore,
                rightValue: battle.opponent.overallScore,
                leftName: battle.player.name,
                rightName: battle.opponent.name
            )
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var muscleComparison: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("muscleBreakdown", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ForEach(muscleComparisonData, id: \.label) { item in
                comparisonBar(
                    leftValue: item.playerScore,
                    rightValue: item.opponentScore,
                    leftName: "",
                    rightName: "",
                    label: item.label
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var muscleComparisonData: [(label: String, playerScore: Double, opponentScore: Double)] {
        let allMuscles: [(key: String, label: String)] = [
            ("chest", "Chest"), ("shoulders", "Shoulders"), ("back", "Back"),
            ("arms", "Arms"), ("legs", "Legs"), ("core", "Core")
        ]
        let visible = Set(sharedVisibleGroups)
        return allMuscles
            .filter { visible.contains($0.key) }
            .compactMap { muscle in
                let pScore = scoreForMuscle(muscle.key, scores: battle.player.muscleScores)
                let oScore = scoreForMuscle(muscle.key, scores: battle.opponent.muscleScores)
                if pScore <= 0 && oScore <= 0 { return nil }
                return (muscle.label, pScore, oScore)
            }
    }

    private func comparisonBar(leftValue: Double, rightValue: Double, leftName: String, rightName: String, label: String? = nil) -> some View {
        VStack(spacing: 6) {
            if let label {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Text(scoreText(leftValue))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(leftValue >= rightValue ? .green : .white.opacity(0.5))
                    .frame(width: 32, alignment: .trailing)

                GeometryReader { geo in
                    let total = max(leftValue + rightValue, 0.1)
                    let leftWidth = max(geo.size.width * (leftValue / total), 4)
                    let rightWidth = max(geo.size.width * (rightValue / total), 4)

                    HStack(spacing: 2) {
                        Capsule()
                            .fill(leftValue >= rightValue ? Color.green : Color.white.opacity(0.15))
                            .frame(width: leftWidth, height: 8)
                        Capsule()
                            .fill(rightValue > leftValue ? Color.red : Color.white.opacity(0.15))
                            .frame(width: rightWidth, height: 8)
                    }
                }
                .frame(height: 8)

                Text(scoreText(rightValue))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(rightValue > leftValue ? .red : .white.opacity(0.5))
                    .frame(width: 32, alignment: .leading)
            }

            if !leftName.isEmpty || !rightName.isEmpty {
                HStack {
                    Text(leftName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                    Text(rightName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showShareCard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text(L.t("shareBattleCard", lang))
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
                Text(L.t("done", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
