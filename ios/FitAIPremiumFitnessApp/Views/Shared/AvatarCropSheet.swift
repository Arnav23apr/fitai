import SwiftUI

/// Apple-style "Move and Scale" crop sheet for the user's custom avatar.
/// Mirrors the Contacts / iMessage flow: full-bleed photo behind a
/// circular viewfinder, pinch and pan to compose, Cancel / Choose pills
/// floating on top — no navigation chrome.
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

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var viewSize: CGSize = .zero
    @State private var appeared: Bool = false

    /// Output JPEG dimensions in pixels. 768pt at quality 0.85 = sharp on
    /// retina while keeping uploads well under the bucket's 5MB cap.
    private let outputSize: CGFloat = 768

    /// Visible crop circle diameter on screen — computed from the smaller
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

                // Full-bleed image. .scaledToFit() inside an .infinity
                // frame lets the photo expand to whichever screen edge
                // it hits first.
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(combinedGesture)

                // Dim everything outside the crop circle. Punch-out mask
                // is composited so the underlying image bleeds through
                // the circle at full brightness.
                Rectangle()
                    .fill(Color.black.opacity(0.6))
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

                // Crop circle ring.
                Circle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                    .allowsHitTesting(false)

                // "Move and Scale" hint — sits below the crop circle in
                // the dimmed area so it doesn't compete with the photo.
                VStack {
                    Spacer()
                    Text("Move and Scale")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, geo.safeAreaInsets.bottom + 24)
                }
                .allowsHitTesting(false)

                // Floating Liquid Glass action pills (Cancel / Choose) on
                // top of everything. Anchored to the top safe-area inset
                // rather than to a navigation bar.
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
            .onAppear {
                viewSize = geo.size
                // Settle the initial offset/scale so the image is
                // perfectly centered behind the crop circle on first
                // appear (handles non-square source aspect ratios).
                resetToFit()
            }
            .onChange(of: geo.size) { _, newSize in viewSize = newSize }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    // MARK: - Gestures

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let proposed = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    offset = clampedOffset(proposed, scale: scale)
                }
                .onEnded { _ in lastOffset = offset },
            MagnificationGesture()
                .onChanged { value in
                    let proposed = max(0.5, min(6.0, lastScale * value))
                    let newScale = clampedScale(proposed)
                    scale = newScale
                    // Max offset shrinks as scale drops, so re-clamp.
                    offset = clampedOffset(offset, scale: newScale)
                }
                .onEnded { _ in
                    lastScale = scale
                    lastOffset = offset
                }
        )
    }

    // MARK: - Clamping (image bounds always cover the crop square)

    /// Smallest scale at which the image's shorter side still fills the
    /// crop circle. Below this the crop would reveal photo edges.
    private func minScale() -> CGFloat {
        let imgSize = sourceImage.size
        guard viewSize.width > 0, viewSize.height > 0,
              imgSize.width > 0, imgSize.height > 0 else { return 1.0 }
        let baseFitScale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let diameter = cropDiameter(in: viewSize)
        let shorterImageSide = min(imgSize.width, imgSize.height)
        let shorterOnScreenAtBase = shorterImageSide * baseFitScale
        guard shorterOnScreenAtBase > 0 else { return 1.0 }
        return diameter / shorterOnScreenAtBase
    }

    private func clampedScale(_ proposed: CGFloat) -> CGFloat {
        max(proposed, minScale())
    }

    /// At a given scale, the image's displayed width/height define how
    /// far the user can pan before an image edge enters the crop square.
    /// Permissible range is ±(displayed - diameter)/2 on each axis.
    private func clampedOffset(_ proposed: CGSize, scale: CGFloat) -> CGSize {
        let imgSize = sourceImage.size
        guard viewSize.width > 0, viewSize.height > 0,
              imgSize.width > 0, imgSize.height > 0 else { return proposed }
        let baseFitScale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let effectiveScale = baseFitScale * scale
        let displayedW = imgSize.width * effectiveScale
        let displayedH = imgSize.height * effectiveScale
        let diameter = cropDiameter(in: viewSize)

        let maxX = max(0, (displayedW - diameter) / 2)
        let maxY = max(0, (displayedH - diameter) / 2)

        return CGSize(
            width: max(-maxX, min(maxX, proposed.width)),
            height: max(-maxY, min(maxY, proposed.height))
        )
    }

    // MARK: - Initial fit

    /// Pre-scale the image so its shorter dimension fills the crop circle
    /// — matches what users expect from Contacts (the photo is already
    /// "framed" by the circle and they only need to fine-tune position).
    private func resetToFit() {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        scale = minScale()
        lastScale = scale
        offset = .zero
        lastOffset = .zero
    }

    // MARK: - Rendering

    /// Replicate the visible transform onto a fixed-size canvas matching
    /// the crop circle's bounding box. Anything outside the canvas is
    /// discarded — which gives us the exact rectangle the user composed.
    private func produceCroppedData(viewSize: CGSize, diameter: CGFloat) -> Data? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let imgSize = sourceImage.size
        let baseFitScale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let effectiveScale = baseFitScale * scale

        // The image's on-screen rect (post-scaledToFit, post-scaleEffect,
        // post-offset). Origin is in screen coordinates.
        let displayedW = imgSize.width * effectiveScale
        let displayedH = imgSize.height * effectiveScale
        let imgOriginX = (viewSize.width - displayedW) / 2 + offset.width
        let imgOriginY = (viewSize.height - displayedH) / 2 + offset.height

        // The crop circle's top-left in screen coordinates.
        let cropOriginX = (viewSize.width - diameter) / 2
        let cropOriginY = (viewSize.height - diameter) / 2

        // Re-express the image rect in the crop circle's coordinate space,
        // then scale that space up to the output canvas.
        let canvasScale = outputSize / diameter
        let canvasImgOriginX = (imgOriginX - cropOriginX) * canvasScale
        let canvasImgOriginY = (imgOriginY - cropOriginY) * canvasScale
        let canvasImgW = displayedW * canvasScale
        let canvasImgH = displayedH * canvasScale

        // Force scale=1 so the pixel dimensions match `outputSize` exactly.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )

        let final = renderer.image { _ in
            sourceImage.draw(in: CGRect(
                x: canvasImgOriginX,
                y: canvasImgOriginY,
                width: canvasImgW,
                height: canvasImgH
            ))
        }

        return final.jpegData(compressionQuality: 0.85)
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
