import SwiftUI

/// 9:16 (1080×1920) shareable recap card rendered after a 1v1 battle resolves.
/// Diptych of both submission photos + AI scores + winner badge + brand mark.
/// The structure (side-by-side faces with the central VS) is the brand
/// asset; cropping kills the comparison so the design absorbs negative space
/// rather than fitting more in.
struct BattleRecapCardView: View {
    let myUsername: String
    let myPhoto: UIImage?
    let myScore: Double

    let theirUsername: String
    let theirPhoto: UIImage?
    let theirScore: Double

    let iWon: Bool

    static let renderSize = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 100)
                    .padding(.bottom, 28)

                photoStack

                Spacer(minLength: 24)

                resultBlock

                Spacer(minLength: 24)

                footer
                    .padding(.bottom, 80)
            }
            .padding(.horizontal, 56)
        }
        .frame(width: Self.renderSize.width, height: Self.renderSize.height)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 18) {
            Image("FitAILogoWhite")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(height: 48)
                .foregroundStyle(.white)

            Text("1v1 PHYSIQUE BATTLE")
                .font(.system(size: 24, weight: .black))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Diptych

    private var photoStack: some View {
        HStack(spacing: 12) {
            photoTile(label: "@\(myUsername)", image: myPhoto, score: myScore, isWinner: iWon)
            photoTile(label: "@\(theirUsername)", image: theirPhoto, score: theirScore, isWinner: !iWon)
        }
        .overlay(alignment: .center) {
            ZStack {
                Circle().fill(.white).frame(width: 64, height: 64)
                Text("VS")
                    .font(.system(size: 22, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.black)
            }
        }
    }

    private func photoTile(label: String, image: UIImage?, score: Double, isWinner: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.04)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.2))
                    )
            }

            // Score badge over the top
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white)
                Text(String(format: "%.1f", score))
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(isWinner ? .yellow : .white)
            }
            .padding(16)
        }
        .frame(width: 478, height: 720)
        .clipShape(.rect(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isWinner ? .yellow.opacity(0.7) : .white.opacity(0.10), lineWidth: 2)
        )
    }

    // MARK: - Result block

    private var resultBlock: some View {
        VStack(spacing: 8) {
            Text(iWon ? "YOU WON" : "GG")
                .font(.system(size: 80, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
            Text(iWon
                 ? "Beat @\(theirUsername) by \(scoreDelta)."
                 : "@\(theirUsername) edged you by \(scoreDelta).")
                .font(.system(size: 24, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var scoreDelta: String {
        String(format: "%.1f", abs(myScore - theirScore))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Text("AI-JUDGED · 1v1")
                .font(.system(size: 14, weight: .heavy))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.4))
            Text("FITAI.HEALTH")
                .font(.system(size: 20, weight: .black))
                .tracking(5)
                .foregroundStyle(.white)
        }
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
