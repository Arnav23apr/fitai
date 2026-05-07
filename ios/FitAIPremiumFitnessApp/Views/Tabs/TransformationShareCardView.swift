import SwiftUI

/// 9:16 Story-sized share card pairing the user's current scan photo with
/// the AI-generated 90-day potential. Pure black + white treatment so the
/// card reads as editorial rather than meme-app. The diptych structure is
/// the brand asset — cropping ruins the comparison.
struct TransformationShareCardView: View {
    let currentPhoto: UIImage?
    let transformedPhoto: UIImage
    let potentialRating: Double?

    /// 9:16 at a render scale that yields a sharp Story asset.
    static let renderSize = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 100)
                    .padding(.bottom, 36)

                photoStack

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
        VStack(spacing: 24) {
            Image("FitAILogoWhite")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(height: 56)
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("90-DAY POTENTIAL")
                    .font(.system(size: 64, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if let rating = potentialRating {
                    Text(String(format: "%.1f / 10", rating))
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    // MARK: - Photo stack — side-by-side before/after

    private var photoStack: some View {
        HStack(spacing: 12) {
            photoTile(label: "TODAY", image: currentPhoto)
            photoTile(label: "DAY 90", image: transformedPhoto)
        }
        .overlay(alignment: .center) {
            // Center arrow badge — sits on the seam between the two photos.
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.black)
            }
        }
    }

    private func photoTile(label: String, image: UIImage?) -> some View {
        // 9:16 outer frame minus 56 padding = 968 of usable width.
        // Two tiles + 12 spacing → each ~478 wide. Height ~860 yields a
        // strong portrait crop without losing too much body.
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.04)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .font(.system(size: 70))
                            .foregroundStyle(.white.opacity(0.20))
                    )
            }

            Text(label)
                .font(.system(size: 18, weight: .black))
                .tracking(4)
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white)
                .padding(16)
        }
        .frame(width: 478, height: 860)
        .clipShape(.rect(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Text("AI-GENERATED VISUALIZATION")
                .font(.system(size: 16, weight: .heavy))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.40))
            Text("FITAI.HEALTH")
                .font(.system(size: 22, weight: .black))
                .tracking(6)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Renderer helper

extension TransformationShareCardView {
    /// Render the card off-screen at full resolution and return a UIImage
    /// suitable for `UIActivityViewController`.
    @MainActor
    static func render(currentPhoto: UIImage?, transformedPhoto: UIImage, potentialRating: Double?) -> UIImage? {
        let view = TransformationShareCardView(
            currentPhoto: currentPhoto,
            transformedPhoto: transformedPhoto,
            potentialRating: potentialRating
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}
