import SwiftUI

struct RankProgressionSheet: View {
    let currentPoints: Int
    @Environment(\.dismiss) private var dismiss

    private var currentTier: CompeteTier { CompeteTier.current(for: currentPoints) }
    private var nextTier: CompeteTier? { CompeteTier.next(for: currentPoints) }

    private var currentTierIndex: Int {
        CompeteTier.tiers.firstIndex(where: { $0.name == currentTier.name }) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    currentRankHeader
                    tiersList
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.clear)
            .navigationTitle("Rank Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var currentRankHeader: some View {
        VStack(spacing: 16) {
            TierBadgeView(tier: currentTier.name, points: currentPoints, size: 72)

            VStack(spacing: 4) {
                Text(currentTier.name.uppercased())
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .tracking(3)
                    .foregroundStyle(gradientFor(currentTier.name))

                Text("\(currentPoints) XP")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            if let next = nextTier {
                let pointsNeeded = next.minPoints - currentPoints
                let progressInTier = Double(currentPoints - currentTier.minPoints)
                let tierRange = Double(next.minPoints - currentTier.minPoints)
                let progress = min(max(progressInTier / tierRange, 0), 1.0)

                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 10)

                            Capsule()
                                .fill(gradientFor(currentTier.name))
                                .frame(width: max(geo.size.width * progress, 10), height: 10)
                                .shadow(color: colorFor(currentTier.name).opacity(0.4), radius: 6)
                        }
                    }
                    .frame(height: 10)
                    .padding(.horizontal, 32)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(colorFor(next.name))
                        Text("\(pointsNeeded) XP")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(next.name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(colorFor(next.name))
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.yellow)
                    Text("Maximum Rank Achieved")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
    }

    private var tiersList: some View {
        VStack(spacing: 0) {
            ForEach(Array(CompeteTier.tiers.enumerated()), id: \.element.name) { index, tier in
                let isCurrent = tier.name == currentTier.name
                let isUnlocked = currentPoints >= tier.minPoints
                let isNext = nextTier?.name == tier.name

                tierRow(
                    tier: tier,
                    index: index,
                    isCurrent: isCurrent,
                    isUnlocked: isUnlocked,
                    isNext: isNext,
                    isLast: index == CompeteTier.tiers.count - 1
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func tierRow(tier: CompeteTier, index: Int, isCurrent: Bool, isUnlocked: Bool, isNext: Bool, isLast: Bool) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? colorFor(tier.name).opacity(0.15) : Color(.systemGray5))
                        .frame(width: 48, height: 48)

                    if isUnlocked {
                        Image(systemName: iconFor(tier.name))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(colorFor(tier.name))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.systemGray3))
                    }

                    if isCurrent {
                        Circle()
                            .strokeBorder(colorFor(tier.name), lineWidth: 2.5)
                            .frame(width: 48, height: 48)
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(isUnlocked ? colorFor(tier.name).opacity(0.3) : Color(.systemGray5))
                        .frame(width: 2, height: 32)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(tier.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isUnlocked ? .primary : .tertiary)

                    if isCurrent {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(colorFor(tier.name))
                            .clipShape(Capsule())
                    } else if isNext {
                        Text("NEXT")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(colorFor(tier.name))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(colorFor(tier.name).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    Label("\(tier.minPoints) XP", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(isUnlocked ? .secondary : .tertiary)

                    if isNext {
                        let pointsNeeded = tier.minPoints - currentPoints
                        Text("\(pointsNeeded) XP to go")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(colorFor(tier.name))
                    } else if isUnlocked && !isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }

                Text(descriptionFor(tier.name))
                    .font(.caption)
                    .foregroundStyle(isUnlocked ? .secondary : .quaternary)
                    .lineLimit(2)

                if isNext {
                    let progressInTier = Double(currentPoints - (CompeteTier.tiers[max(index - 1, 0)].minPoints))
                    let tierRange = Double(tier.minPoints - CompeteTier.tiers[max(index - 1, 0)].minPoints)
                    let progress = min(max(progressInTier / tierRange, 0), 1.0)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 5)
                            Capsule()
                                .fill(colorFor(tier.name))
                                .frame(width: max(geo.size.width * progress, 5), height: 5)
                        }
                    }
                    .frame(height: 5)
                    .padding(.trailing, 20)
                }
            }

            Spacer()
        }
        .padding(.vertical, isCurrent ? 14 : 10)
        .padding(.horizontal, 14)
        .background(
            Group {
                if isCurrent {
                    colorFor(tier.name).opacity(0.06)
                } else if isNext {
                    colorFor(tier.name).opacity(0.03)
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(.rect(cornerRadius: 16))
    }

    private func colorFor(_ tier: String) -> Color {
        switch tier {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }

    private func gradientFor(_ tier: String) -> LinearGradient {
        let primary = colorFor(tier)
        let secondary: Color
        switch tier {
        case "Silver": secondary = Color(red: 0.6, green: 0.6, blue: 0.65)
        case "Gold": secondary = Color(red: 0.85, green: 0.65, blue: 0.0)
        case "Platinum": secondary = Color(red: 0.4, green: 0.6, blue: 0.85)
        case "Diamond": secondary = Color(red: 0.4, green: 0.7, blue: 1.0)
        default: secondary = Color(red: 0.65, green: 0.35, blue: 0.10)
        }
        return LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    private func iconFor(_ tier: String) -> String {
        switch tier {
        case "Diamond": return "diamond.fill"
        case "Platinum": return "crown.fill"
        case "Gold": return "star.fill"
        case "Silver": return "shield.fill"
        default: return "shield.fill"
        }
    }

    private func descriptionFor(_ tier: String) -> String {
        switch tier {
        case "Bronze": return "Just getting started. Every rep counts."
        case "Silver": return "Building momentum. You're on the rise."
        case "Gold": return "Serious dedication. The grind is paying off."
        case "Platinum": return "Elite status. Few make it this far."
        case "Diamond": return "Top tier. You are the competition."
        default: return ""
        }
    }
}
