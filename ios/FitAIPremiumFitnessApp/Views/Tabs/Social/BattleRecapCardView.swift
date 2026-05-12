import SwiftUI

/// Shareable recap card rendered after a 1v1 Compete challenge resolves.
/// Mirrors the visual language of `BattleShareCardView` (the local 1v1
/// physique battle) so the brand-shareable image is consistent across
/// both entry points: photo circles with gradient borders, MOGGED stamp
/// on the loser, crown header, brand mark.
///
/// Difference vs `BattleShareCardView`: per-muscle scores aren't shown
/// here because the challenge table only persists each side's *overall*
/// score, not the full breakdown. If the schema grows to store the
/// per-muscle JSON on submit, this card should grow the score grid back
/// in to fully match `BattleShareCardView`.
struct BattleRecapCardView: View {
    let myUsername: String
    let myPhoto: UIImage?
    let myScore: Double

    let theirUsername: String
    let theirPhoto: UIImage?
    let theirScore: Double

    let iWon: Bool

    /// Same render dimensions as the legacy version so callers don't have
    /// to recompute layout. Kept for API parity; the inner card auto-
    /// centers inside this canvas.
    static let renderSize = CGSize(width: 1080, height: 1920)

    private let cardBg = Color(red: 0.07, green: 0.07, blue: 0.08)
    private var scoreDifference: Double { abs(myScore - theirScore) }
    private var winnerName: String { iWon ? "@\(myUsername)" : "@\(theirUsername)" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer(minLength: 0)

                cardBody

                Spacer(minLength: 0)

                Image("FitAILogoWhite")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .opacity(0.55)
                    .padding(.bottom, 60)
            }
        }
        .frame(width: Self.renderSize.width, height: Self.renderSize.height)
    }

    /// The actual card. Scaled to fill most of the canvas width with
    /// generous breathing room above and below.
    private var cardBody: some View {
        VStack(spacing: 0) {
            Text("Physique Battle")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 56)
                .padding(.bottom, 14)

            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.yellow)
                Text("\(winnerName) wins by \(String(format: "%.1f", scoreDifference))!")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(.bottom, 48)

            HStack(alignment: .top, spacing: 24) {
                contestantBlock(
                    label: "@\(myUsername)",
                    photo: myPhoto,
                    score: myScore,
                    isWinner: iWon
                )

                Text("VS")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 140)

                contestantBlock(
                    label: "@\(theirUsername)",
                    photo: theirPhoto,
                    score: theirScore,
                    isWinner: !iWon
                )
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 52)
        }
        .frame(width: 920)
        .background(cardBg)
        .clipShape(.rect(cornerRadius: 44))
    }

    private func contestantBlock(label: String, photo: UIImage?, score: Double, isWinner: Bool) -> some View {
        let isMogged = !isWinner && scoreDifference >= 0.5

        return VStack(spacing: 0) {
            ZStack {
                photoCircle(image: photo, isWinner: isWinner)

                if isMogged {
                    Text("MOGGED")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.red, lineWidth: 3)
                        )
                        .clipShape(.rect(cornerRadius: 6))
                        .rotationEffect(.degrees(-12))
                        .offset(y: 60)
                }
            }
            .padding(.top, 36)
            .padding(.bottom, isMogged ? 56 : 32)

            Text(label)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .padding(.bottom, 24)

            VStack(spacing: 6) {
                Text("Overall")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text(String(format: "%.1f", score))
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(isWinner ? .green : .white)
                    .shadow(color: isWinner ? .green.opacity(0.32) : .clear, radius: 24, y: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                isWinner ? Color.green.opacity(0.20) : Color.white.opacity(0.08),
                                lineWidth: 2
                            )
                    )
            )
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func photoCircle(image: UIImage?, isWinner: Bool) -> some View {
        let size: CGFloat = 220
        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.25))
                    )
            }
        }
        .overlay(
            Circle()
                .strokeBorder(
                    isWinner
                        ? LinearGradient(
                            colors: [.green.opacity(0.85), .mint.opacity(0.60), .green.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [.red.opacity(0.55), .red.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ),
                    lineWidth: 6
                )
        )
        .shadow(color: isWinner ? .green.opacity(0.30) : .clear, radius: 26, y: 8)
    }
}

// MARK: - Renderer

extension BattleRecapCardView {
    @MainActor
    static func render(
        myUsername: String,
        myPhoto: UIImage?,
        myScore: Double,
        theirUsername: String,
        theirPhoto: UIImage?,
        theirScore: Double,
        iWon: Bool
    ) -> UIImage? {
        let view = BattleRecapCardView(
            myUsername: myUsername,
            myPhoto: myPhoto,
            myScore: myScore,
            theirUsername: theirUsername,
            theirPhoto: theirPhoto,
            theirScore: theirScore,
            iWon: iWon
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}
