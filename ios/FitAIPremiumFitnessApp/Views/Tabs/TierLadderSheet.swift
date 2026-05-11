import SwiftUI

struct TierLadderSheet: View {
    let score: Double
    let gender: String
    @Environment(\.dismiss) private var dismiss

    private struct Band: Identifiable {
        let id: Int
        let rangeLabel: String
        let minScore: Double
        let upperBoundExclusive: Double?
        let maleRank: PhysiqueRank
        let femaleRank: PhysiqueRank
    }

    private var bands: [Band] {
        [
            Band(id: 0, rangeLabel: "8.0+",    minScore: 8.0, upperBoundExclusive: nil,  maleRank: .leaveSome,    femaleRank: .uSingle),
            Band(id: 1, rangeLabel: "7.0-7.9", minScore: 7.0, upperBoundExclusive: 8.0,  maleRank: .nattyBro,     femaleRank: .gymCrush),
            Band(id: 2, rangeLabel: "6.0-6.9", minScore: 6.0, upperBoundExclusive: 7.0,  maleRank: .mogger,       femaleRank: .gymBaddie),
            Band(id: 3, rangeLabel: "5.0-5.9", minScore: 5.0, upperBoundExclusive: 6.0,  maleRank: .gymBro,       femaleRank: .muscleMommy),
            Band(id: 4, rangeLabel: "4.0-4.9", minScore: 4.0, upperBoundExclusive: 5.0,  maleRank: .gettingThere, femaleRank: .gettingThere),
            Band(id: 5, rangeLabel: "2.0-3.9", minScore: 2.0, upperBoundExclusive: 4.0,  maleRank: .workHarder,   femaleRank: .workHarder),
            Band(id: 6, rangeLabel: "Below 2", minScore: 0.0, upperBoundExclusive: 2.0,  maleRank: .itsOver,      femaleRank: .itsOver),
        ]
    }

    private var isFemale: Bool {
        let g = gender.lowercased()
        return g.contains("female") || g == "woman" || g == "f"
    }

    private func rank(for band: Band) -> PhysiqueRank {
        isFemale ? band.femaleRank : band.maleRank
    }

    private func isCurrent(_ band: Band) -> Bool {
        if let upper = band.upperBoundExclusive {
            return score >= band.minScore && score < upper
        }
        return score >= band.minScore
    }

    private var displayScore: String {
        String(format: "%.1f", Double(Int(round(score * 10))) / 10)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(bands) { band in
                        row(band)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Tier ladder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("You're at \(displayScore) / 10")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ band: Band) -> some View {
        let rank = rank(for: band)
        let current = isCurrent(band)
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(rank.color)
                .frame(width: 4, height: 32)

            Text(rank.emoji.isEmpty ? "•" : rank.emoji)
                .font(.system(size: 22))
                .frame(width: 28)

            Text(rank.label)
                .font(.system(size: 15, weight: current ? .bold : .semibold))
                .foregroundStyle(.white.opacity(current ? 1.0 : 0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(band.rangeLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(current ? rank.color.opacity(0.18) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(current ? rank.color.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
