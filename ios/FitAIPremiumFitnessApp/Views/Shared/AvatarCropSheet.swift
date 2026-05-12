import SwiftUI

/// Apple-style "Move and Scale" crop sheet for the user's custom avatar.
/// Mirrors the Contacts / iMessage flow: full-bleed photo behind a
/// circular viewfinder, pinch and pan to compose, Cancel / Choose pills
/// floating on top, no navigation chrome.
///
/// Pinch+pan is delegated to a UIScrollView subclass, which gives the
/// same hardware-accelerated, around-the-centroid zoom that Instagram
/// and Apple's own Photos picker use. Layout happens in the scroll
/// view's own `layoutSubviews` so it always picks up the correct bounds
/// (SwiftUI's `updateUIView` can fire before bounds settle).
///
/// Output is a square JPEG sized to the visible crop circle's bounding
/// box, so the rest of the app can keep applying `.clipShape(Circle())`
/// at render time without re-cropping.
struct AvatarCropSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The full-resolution UIImage the user just picked.
    let sourceImage: UIImage

    /// Called with the cropped JPEG data when the user taps "Choose".
    let onCrop: (Data) -> Void

    @State private var controller = CropController()
    @State private var appeared: Bool = false

    /// Output JPEG dimensions in pixels. 768pt at quality 0.85 = sharp on
    /// retina while keeping uploads well under the bucket's 5MB cap.
    private let outputSize: CGFloat = 768

    /// Visible crop circle diameter on screen, computed from the smaller
    /// screen dimension so the circle fills most of the width on any
    /// device while leaving room for the floating button pills.
    private func cropDiameter(in size: CGSize) -> CGFloat {
        min(size.width, size.height) - 60
    }

    var body: some View {
        GeometryReader { geo in
            let diameter = cropDiameter(in: geo.size)

            ZStack {
                Color.black.ignoresSafeArea()

                ZoomableImageView(
                    image: sourceImage,
                    cropDiameter: diameter,
                    controller: controller
                )
                .ignoresSafeArea()

                // Outside-the-circle tint. Lower opacity than a full
                // dimmer so the surrounding photo stays readable while
                // still letting the crop area pop.
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .mask {
                        ZStack {
                            Rectangle()
                            Circle()
                                .frame(width: diameter, height: diameter)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .allowsHitTesting(false)

                // Crop circle ring. Slightly thicker + softer shadow so
                // it reads against both bright and dark photos.
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 2)
                    .allowsHitTesting(false)

                // "Move and Scale" hint sits below the crop circle in
                // the dimmed area so it doesn't compete with the photo.
                VStack {
                    Spacer()
                    Text("Move and Scale")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, geo.safeAreaInsets.bottom + 24)
                }
                .allowsHitTesting(false)

                // Floating Liquid Glass action pills (Cancel / Choose)
                // on top of everything. Anchored to the top safe-area
                // inset rather than to a navigation bar.
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .modifier(GlassPill(prominent: false))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            if let data = produceCroppedData(viewSize: geo.size, diameter: diameter) {
                                onCrop(data)
                            }
                            dismiss()
                        } label: {
                            Text("Choose")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .modifier(GlassPill(prominent: true))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.success, trigger: appeared)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { appeared = true }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    // MARK: - Rendering

    /// Translates the scroll view's pan/zoom state into a source-image
    /// rect, then renders that rect into a fixed-size square canvas.
    private func produceCroppedData(viewSize: CGSize, diameter: CGFloat) -> Data? {
        let zoomScale = controller.zoomScale
        guard viewSize.width > 0, viewSize.height > 0, zoomScale > 0 else { return nil }

        // Crop circle's top-left in scroll-view bounds (centered).
        let cropTopLeftInBounds = CGPoint(
            x: (viewSize.width - diameter) / 2,
            y: (viewSize.height - diameter) / 2
        )

        // Translate to scroll view content coords (which is what
        // contentOffset is expressed in).
        let cropTopLeftInContent = CGPoint(
            x: controller.contentOffset.x + cropTopLeftInBounds.x,
            y: controller.contentOffset.y + cropTopLeftInBounds.y
        )

        // The image view's bounds are the natural image size, so one
        // content-coord unit equals 1 / zoomScale source pixels.
        let pxPerContent = 1.0 / zoomScale
        let srcRect = CGRect(
            x: cropTopLeftInContent.x * pxPerContent,
            y: cropTopLeftInContent.y * pxPerContent,
            width: diameter * pxPerContent,
            height: diameter * pxPerContent
        )

        // Force scale=1 so the pixel dimensions match `outputSize` exactly.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )

        let final = renderer.image { _ in
            // Map srcRect onto (0, 0, outputSize, outputSize) by drawing
            // the full image with origin/size shifted so that srcRect
            // ends up filling the canvas.
            let scaleX = outputSize / srcRect.width
            let scaleY = outputSize / srcRect.height
            let drawRect = CGRect(
                x: -srcRect.minX * scaleX,
                y: -srcRect.minY * scaleY,
                width: sourceImage.size.width * scaleX,
                height: sourceImage.size.height * scaleY
            )
            sourceImage.draw(in: drawRect)
        }

        return final.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Scroll state container

/// Plain class held in `@State`. Reference semantics let the UIScrollView
/// delegate write at 60fps without going through SwiftUI; the parent
/// just reads the latest values at "Choose" time.
final class CropController {
    var contentOffset: CGPoint = .zero
    var zoomScale: CGFloat = 1.0
}

// MARK: - UIScrollView-backed image

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let cropDiameter: CGFloat
    let controller: CropController

    func makeUIView(context: Context) -> CropScrollView {
        let scroll = CropScrollView()
        scroll.controller = controller
        scroll.configure(image: image, cropDiameter: cropDiameter)
        return scroll
    }

    func updateUIView(_ scroll: CropScrollView, context: Context) {
        scroll.controller = controller
        if scroll.cropDiameter != cropDiameter {
            scroll.cropDiameter = cropDiameter
            scroll.setNeedsLayout()
        }
    }
}

/// UIScrollView subclass that owns its own layout. Doing it here (rather
/// than in `updateUIView`) guarantees we re-run when bounds change,
/// which is when SwiftUI's container finishes its layout pass.
final class CropScrollView: UIScrollView, UIScrollViewDelegate {
    let displayImageView = UIImageView()
    weak var controller: CropController?
    var cropDiameter: CGFloat = 0
    private var sourceImage: UIImage?
    private var didInitialCenter = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        bouncesZoom = true
        bounces = true
        // Force pan recognition even when contentSize is close to bounds.
        // The contentInset still defines the legal scroll range.
        alwaysBounceVertical = true
        alwaysBounceHorizontal = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
        decelerationRate = .fast
        // Image bleeds outside the visible crop circle on purpose; the
        // overlay handles the dim mask, so don't clip.
        clipsToBounds = false

        displayImageView.contentMode = .scaleAspectFill
        displayImageView.isUserInteractionEnabled = false
        addSubview(displayImageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(image: UIImage, cropDiameter: CGFloat) {
        self.sourceImage = image
        self.cropDiameter = cropDiameter
        displayImageView.image = image
        displayImageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = sourceImage,
              bounds.size.width > 0,
              bounds.size.height > 0,
              cropDiameter > 0 else { return }

        let imageSize = image.size
        // Base scale = the zoom factor at which the shorter image side
        // exactly fills the crop circle.
        let base = max(cropDiameter / imageSize.width,
                       cropDiameter / imageSize.height)

        // Apply zoom limits once. Subsequent layout passes (rotation,
        // sheet resize) don't need to reset zoom since the bounds-based
        // formula is invariant.
        if abs(minimumZoomScale - base) > 0.0001 {
            minimumZoomScale = base
            maximumZoomScale = base * 6
            setZoomScale(base, animated: false)
        }

        // Insets let the user pan any image edge to align with the
        // crop circle edge without scrollView clamping the offset first.
        let insetX = max(0, (bounds.width - cropDiameter) / 2)
        let insetY = max(0, (bounds.height - cropDiameter) / 2)
        contentInset = UIEdgeInsets(top: insetY, left: insetX,
                                    bottom: insetY, right: insetX)

        // Center the image so the crop circle sits over its midpoint.
        if !didInitialCenter {
            let scaledSize = CGSize(
                width: imageSize.width * zoomScale,
                height: imageSize.height * zoomScale
            )
            let centered = CGPoint(
                x: scaledSize.width / 2 - bounds.width / 2,
                y: scaledSize.height / 2 - bounds.height / 2
            )
            setContentOffset(centered, animated: false)
            didInitialCenter = true
        }

        controller?.zoomScale = zoomScale
        controller?.contentOffset = contentOffset
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        displayImageView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        controller?.contentOffset = scrollView.contentOffset
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        controller?.zoomScale = scrollView.zoomScale
        controller?.contentOffset = scrollView.contentOffset
    }
}

/// Floating Liquid Glass pill used for the Cancel / Choose buttons over
/// the crop preview. `prominent` makes the glass brighter (Choose) vs
/// the more transparent base (Cancel). Falls back to `.ultraThinMaterial`
/// on iOS < 26 so the buttons stay legible.
private struct GlassPill: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(.white.opacity(prominent ? 0.22 : 0.06))
                        .interactive(),
                    in: .capsule
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(prominent ? 0.45 : 0.30),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
        } else {
            content
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(prominent ? 0.40 : 0.22),
                                    .white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .environment(\.colorScheme, .dark)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
        }
    }
}
