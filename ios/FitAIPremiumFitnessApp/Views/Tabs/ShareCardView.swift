import SwiftUI

struct ShareCardView: View {
    let result: ScanResult
    /// User's gender (`profile.gender`). Required to pick the correct
    /// gendered tier label (`gym bro` vs `muscle mommy`, etc.). Empty
    /// string is acceptable, falls back to the male variant.
    var gender: String = ""
    /// User's date of birth, used to tailor the percentile claim
    /// ("top 18% of 24-year-old males"). Optional; when nil we fall back
    /// to a gender-only cohort line.
    var dateOfBirth: Date? = nil
    /// When true, the static share-image variant renders. All in-app-only
    /// elements (tier ladder affordance, muscle-mass chip, visible-muscles
    /// disclosure, physique summary, weakest-muscle callout) are skipped so
    /// the exported image stays visually identical to the historical share
    /// card.
    var shareMode: Bool = false

    @State private var showTierLadder: Bool = false
    @State private var summaryExpanded: Bool = false

    private var rank: PhysiqueRank {
        PhysiqueRank.rank(score: result.overallScore, gender: gender)
    }

    private var allScores: [(label: String, score: Double)] {
        // Source of truth for visibility is `visibleMuscleGroups` (the AI
        // returns this array of keys it could actually see). We DO NOT rely
        // on `score > 0` alone because the model occasionally hallucinates
        // a number for a muscle group it can't see — front-facing photo
        // returning a Back score, etc. The visibility filter is the
        // safety net; score > 0 is the secondary guard.
        let visible = Set(result.visibleMuscleGroups.map { $0.lowercased() })
        let scores: [(key: String, label: String, score: Double)] = [
            ("chest", "Chest", result.muscleScores.chest),
            ("shoulders", "Shoulders", result.muscleScores.shoulders),
            ("back", "Back", result.muscleScores.back),
            ("arms", "Arms", result.muscleScores.arms),
            ("legs", "Legs", result.muscleScores.legs),
            ("glutes", "Glutes", result.muscleScores.glutes),
            ("core", "Core", result.muscleScores.core),
        ]
        return scores
            .filter { visible.contains($0.key) && $0.score > 0 }
            .map { ($0.label, $0.score) }
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

    /// Same as `gridRows` but skipping the very first score because the
    /// first one is promoted into the top row alongside Potential.
    private var gridRowsAfterFirst: [[(label: String, score: Double)]] {
        let scores = Array(allScores.dropFirst())
        var rows: [[(label: String, score: Double)]] = []
        var i = 0
        while i < scores.count {
            if i + 1 < scores.count {
                rows.append([scores[i], scores[i + 1]])
                i += 2
            } else {
                rows.append([scores[i]])
                i += 1
            }
        }
        return rows
    }

    /// Visible-muscle labels NOT included in this scan. Used by the
    /// disclosure line so users know the score is based only on what
    /// the AI could see.
    private var missingMuscleLabels: [String] {
        let visible = Set(result.visibleMuscleGroups.map { $0.lowercased() })
        let all: [(key: String, label: String)] = [
            ("chest", "Chest"), ("shoulders", "Shoulders"), ("back", "Back"),
            ("arms", "Arms"), ("legs", "Legs"), ("glutes", "Glutes"), ("core", "Core"),
        ]
        return all.filter { !visible.contains($0.key) }.map { $0.label }
    }

    /// Lowest-scoring visible muscle, used for the "Focus area" callout.
    /// Returns nil when there's fewer than 2 visible muscles or when the
    /// spread between best and worst is < 0.5 (no meaningful weakest).
    private var weakestVisibleScore: (label: String, score: Double)? {
        guard allScores.count >= 2 else { return nil }
        let scores = allScores.map { $0.score }
        guard let mn = scores.min(), let mx = scores.max(), mx - mn >= 0.5 else { return nil }
        return allScores.min(by: { $0.score < $1.score })
    }

    /// Hero score, sized to match the large score cells below (Potential,
    /// Chest) so it reads as part of the same numeric language rather than
    /// dwarfing them.
    private var heroScoreBlock: some View {
        let display = String(format: "%.1f", Double(Int(round(result.overallScore * 10))) / 10)
        return HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(display)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("/10")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.40))
        }
        .blur(radius: result.isLocked ? 9 : 0)
        .shadow(color: rank.color.opacity(0.35), radius: 12, y: 4)
    }

    private let cardBg = Color(red: 0.07, green: 0.07, blue: 0.08)

    var body: some View {
        VStack(spacing: 14) {
            ratedCard

            // Below-card insights (in-app only). These live outside the
            // dark card so the card itself stays the screenshot-able
            // centerpiece. The share render skips this entire block.
            if !shareMode {
                VStack(spacing: 12) {
                    muscleMassChip
                    visibleDisclosure
                    physiqueSummary
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(width: 360)
        .sheet(isPresented: $showTierLadder) {
            TierLadderSheet(score: result.overallScore, gender: gender)
        }
    }

    /// The dark rounded card itself. Everything that ships in the
    /// exported share image lives here.
    private var ratedCard: some View {
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
                    .padding(.bottom, 16)
            }

            // Hero score: the giant number is the screenshot money shot.
            // Sits between photo and tier pill. Blurred for locked results so
            // free users see the structure (centered hero) but not the value.
            heroScoreBlock
                .padding(.bottom, 14)

            // Tier pill, gendered, score-derived label with emoji.
            // In !shareMode the whole pill is tappable and opens the tier
            // ladder sheet; share render falls through to a static pill.
            tierPillContainer
                .padding(.bottom, 8)

            // Percentile claim: "top 18% of 24-year-old males". Static
            // benchmark for v1; replaced with real cohort data later.
            Text(PercentileBenchmark.claim(score: result.overallScore,
                                           gender: gender,
                                           dateOfBirth: dateOfBirth))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .blur(radius: result.isLocked ? 8 : 0)
                .padding(.bottom, 22)

            // Scores card (Potential + muscle scores, Overall is now the hero)
            VStack(spacing: 18) {
                HStack(spacing: 20) {
                    scoreCell(label: "Potential", score: result.potentialRating, isLarge: true, customColor: potentialColor(result.potentialRating))
                    if let first = allScores.first {
                        scoreCell(label: first.label, score: first.score, isLarge: true, customColor: nil)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }

                // Muscle scores grid (skip the first one, it was promoted above)
                ForEach(Array(gridRowsAfterFirst.enumerated()), id: \.offset) { _, row in
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

            // Weakest-muscle "focus area" callout (in-app only).
            if !shareMode {
                weakestCallout
            }

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

    // MARK: - Tier Pill

    private var tierPill: some View {
        let tierColor = rank.color
        return HStack(spacing: 6) {
            if !rank.leadingEmoji.isEmpty {
                Text(rank.leadingEmoji)
                    .font(.system(size: 14))
            }
            Text(rank.label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            if !rank.emoji.isEmpty {
                Text(rank.emoji)
                    .font(.system(size: 14))
            }
            if !shareMode {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [tierColor.opacity(0.35), tierColor.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule().strokeBorder(tierColor.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    /// Wraps `tierPill` in a tap target when rendering in-app. In share
    /// mode the pill renders as a plain capsule with no affordance.
    @ViewBuilder
    private var tierPillContainer: some View {
        if shareMode {
            tierPill
                .blur(radius: result.isLocked ? 9 : 0)
        } else {
            Button {
                guard !result.isLocked else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showTierLadder = true
            } label: {
                tierPill
            }
            .buttonStyle(.plain)
            .disabled(result.isLocked)
            .blur(radius: result.isLocked ? 9 : 0)
        }
    }

    // MARK: - In-app only sections

    @ViewBuilder
    private var muscleMassChip: some View {
        let label = result.muscleMassRating.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .blur(radius: result.isLocked ? 7 : 0)
        }
    }

    @ViewBuilder
    private var visibleDisclosure: some View {
        let missing = missingMuscleLabels
        if !missing.isEmpty && !result.visibleMuscleGroups.isEmpty {
            Text("Not graded this scan: \(missing.joined(separator: ", "))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    @ViewBuilder
    private var physiqueSummary: some View {
        let trimmed = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Text(trimmed)
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .lineLimit(summaryExpanded ? nil : 3)
                .padding(.horizontal, 28)
                .blur(radius: result.isLocked ? 8 : 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !result.isLocked else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        summaryExpanded.toggle()
                    }
                }
        }
    }

    @ViewBuilder
    private var weakestCallout: some View {
        if let weakest = weakestVisibleScore {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(barColor(weakest.score))
                HStack(spacing: 0) {
                    Text("Focus area: ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(weakest.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(barColor(weakest.score))
                }
            }
            .padding(.top, 14)
            .blur(radius: result.isLocked ? 7 : 0)
        }
    }

    // MARK: - Score Cell

    private func scoreCell(label: String, score: Double, isLarge: Bool, customColor: Color?) -> some View {
        let scaled = Int(round(score * 10))
        let color = customColor ?? barColor(score)
        // When the result is locked (free user pre-paywall), blur just the
        // numeric score and the progress bar. The label stays sharp so users
        // see "Chest", "Legs", "Overall" etc and understand what they're
        // unlocking, only the actual numbers are hidden.
        let blurAmount: CGFloat = result.isLocked ? 9 : 0

        return VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: isLarge ? 14 : 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            Text("\(scaled)")
                .font(.system(size: isLarge ? 44 : 36, weight: .bold, design: .rounded))
                .foregroundStyle(customColor != nil ? color : .white)
                .blur(radius: blurAmount)

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
            .blur(radius: blurAmount)
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
    static func render(result: ScanResult, gender: String = "") -> UIImage? {
        // shareMode: true keeps the exported image visually identical to the
        // legacy share card. In-app additions (tier ladder affordance,
        // muscle-mass chip, visible-muscles disclosure, summary blurb,
        // weakest-muscle callout) are skipped.
        let view = ShareCardView(result: result, gender: gender, shareMode: true)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
