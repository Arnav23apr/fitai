import SwiftUI
import Combine
import AVFoundation
import Photos
import PhotosUI

// MARK: - Liquid glass button helper

private extension View {
    @ViewBuilder
    func glassCircleButton() -> some View {
        if #available(iOS 26.0, *) {
            self
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            self
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - ScanCameraView (Instagram/WhatsApp-style camera)

struct ScanCameraView: View {
    let label: String
    let onImageSelected: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @State private var recentPhotos: [PHAsset] = []
    @State private var showFullPicker: Bool = false
    @State private var fullPickerItem: PhotosPickerItem? = nil
    @State private var flashOn: Bool = false
    @State private var shutterScale: CGFloat = 1.0
    @State private var showPhotoTips: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen camera preview (edge-to-edge)
                cameraBackground
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Corner brackets — inset from camera edges
                cornerBrackets
                    .padding(.horizontal, 20)
                    .padding(.top, geo.safeAreaInsets.top + 60)
                    .padding(.bottom, 260)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Overlaid controls
                VStack(spacing: 0) {
                    // Top bar — sits inside safe area with breathing room
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                    Spacer()

                    // Label chip
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(.capsule)
                        .padding(.bottom, 14)

                    // Gallery strip
                    galleryStrip
                        .padding(.bottom, 20)

                    // Bottom controls
                    bottomControls
                        .padding(.bottom, 8)
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            camera.configure()
            loadRecentPhotos()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: flashOn) { _, on in
            camera.setFlash(on)
        }
        .onChange(of: fullPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onImageSelected(image)
                    dismiss()
                }
            }
        }
        .photosPicker(isPresented: $showFullPicker, selection: $fullPickerItem, matching: .images)
        .sheet(isPresented: $showPhotoTips) {
            PhotoTipsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Full-screen camera background

    @ViewBuilder
    private var cameraBackground: some View {
        #if targetEnvironment(simulator)
        simulatorPlaceholder
        #else
        if camera.isReady {
            CameraPreviewLayer(session: camera.session)
        } else {
            simulatorPlaceholder
        }
        #endif
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .glassCircleButton()
            .accessibilityLabel("Close camera")

            Spacer()

            // Photo guidelines (?)
            Button { showPhotoTips = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .glassCircleButton()
            .accessibilityLabel("Photo tips")

            // Flash
            Button { flashOn.toggle() } label: {
                Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(flashOn ? .yellow : .white)
            }
            .glassCircleButton()
            .accessibilityLabel(flashOn ? "Turn off flash" : "Turn on flash")
        }
    }

    // MARK: - Simulator Placeholder

    private var simulatorPlaceholder: some View {
        ZStack {
            Color(white: 0.12)
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Camera Preview")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 32
            let lw: CGFloat = 3.5

            Path { p in
                // Top-left
                p.move(to: CGPoint(x: 0, y: len))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: len, y: 0))
                // Top-right
                p.move(to: CGPoint(x: w - len, y: 0))
                p.addLine(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: len))
                // Bottom-right
                p.move(to: CGPoint(x: w, y: h - len))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w - len, y: h))
                // Bottom-left
                p.move(to: CGPoint(x: len, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: h - len))
            }
            .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
    }

    // MARK: - Gallery Strip

    private var galleryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(recentPhotos.prefix(20), id: \.localIdentifier) { asset in
                    GalleryThumbnail(asset: asset) { image in
                        onImageSelected(image)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 64)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Gallery button
            Button { showFullPicker = true } label: {
                if let first = recentPhotos.first {
                    GalleryThumbnailImage(asset: first)
                        .frame(width: 46, height: 46)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .glassCircleButton()
                }
            }
            .frame(width: 46)

            Spacer()

            // Shutter button
            Button {
                shutterScale = 0.85
                withAnimation(.spring(duration: 0.15)) { shutterScale = 1.0 }
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 5)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(.white)
                        .frame(width: 62, height: 62)
                }
                .scaleEffect(shutterScale)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: shutterScale)
            .accessibilityLabel("Take photo")

            Spacer()

            // Flip camera
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .glassCircleButton()
            .frame(width: 46)
            .accessibilityLabel("Switch camera")
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Actions

    private func capturePhoto() {
        camera.capturePhoto { image in
            onImageSelected(image)
            dismiss()
        }
    }

    private func loadRecentPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            fetchPhotos()
        } else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async { fetchPhotos() }
                }
            }
        }
    }

    private func fetchPhotos() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 20
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        recentPhotos = assets
    }
}

// MARK: - Gallery Thumbnail (tappable)

private struct GalleryThumbnail: View {
    let asset: PHAsset
    let onSelect: (UIImage) -> Void
    @State private var thumb: UIImage?

    var body: some View {
        Button {
            loadFullImage()
        } label: {
            Group {
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: opts
        ) { image, _ in
            if let image { thumb = image }
        }
    }

    private func loadFullImage() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.isSynchronous = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: opts
        ) { image, info in
            let degraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if let image, !degraded {
                onSelect(image)
            }
        }
    }
}

// MARK: - Gallery Thumbnail Image (non-tappable, just for display)

private struct GalleryThumbnailImage: View {
    let asset: PHAsset
    @State private var thumb: UIImage?

    var body: some View {
        Group {
            if let thumb {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .onAppear {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 100, height: 100),
                contentMode: .aspectFill,
                options: opts
            ) { image, _ in
                if let image { thumb = image }
            }
        }
    }
}

// MARK: - AVCaptureSession Camera Model

@MainActor
private class CameraModel: NSObject, ObservableObject {
    @Published var isReady: Bool = false
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var usingFront: Bool = false
    private var flashEnabled: Bool = false
    private var photoContinuation: ((UIImage) -> Void)?

    func configure() {
        guard !isReady else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            addDevice(device)
        }

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isReady = true
            }
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func setFlash(_ on: Bool) {
        flashEnabled = on
    }

    func flipCamera() {
        usingFront.toggle()
        session.beginConfiguration()

        for input in session.inputs {
            session.removeInput(input)
        }

        let position: AVCaptureDevice.Position = usingFront ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            addDevice(device)
        }

        session.commitConfiguration()
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoContinuation = completion
        let settings = AVCapturePhotoSettings()
        if flashEnabled, let device = currentDevice, device.hasFlash {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func addDevice(_ device: AVCaptureDevice) {
        currentDevice = device
        if let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor [weak self] in
            self?.photoContinuation?(image)
            self?.photoContinuation = nil
        }
    }
}

// MARK: - AVCaptureSession Preview (UIKit bridge)

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
