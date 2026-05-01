import SwiftUI
import AVFoundation
import CryptoKit

/// Premium-feeling exercise demo view.
/// Plays a silent looping MP4 when one is provided. Falls back to a smooth
/// UIKit cross-dissolve between still frames (used while the production MP4
/// pipeline isn't run yet).
struct LoopingVideoView: View {
    let videoURL: String
    let thumbnailURL: String
    let frames: [String]

    @State private var localFileURL: URL?
    @State private var isLoadingVideo: Bool = false

    init(videoURL: String, thumbnailURL: String, frames: [String] = []) {
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.frames = frames
    }

    private var hasVideo: Bool { !videoURL.isEmpty }
    private var hasFrames: Bool { frames.count >= 2 && !hasVideo }

    var body: some View {
        ZStack {
            // Premium ambient backdrop
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if hasFrames {
                CrossfadeFramesView(urls: frames)
            } else if hasVideo, let localFileURL {
                LoopingPlayerLayer(fileURL: localFileURL)
                    .transition(.opacity)
            } else if !thumbnailURL.isEmpty {
                AsyncImage(url: URL(string: thumbnailURL)) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    }
                }
            }

            if isLoadingVideo && localFileURL == nil {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .task(id: videoURL) {
            await loadVideo()
        }
        .animation(.easeInOut(duration: 0.25), value: localFileURL)
    }

    @MainActor
    private func loadVideo() async {
        guard !videoURL.isEmpty, let remote = URL(string: videoURL) else {
            localFileURL = nil
            return
        }

        if let cached = ExerciseVideoCache.shared.cachedFile(for: videoURL) {
            localFileURL = cached
            return
        }

        isLoadingVideo = true
        defer { isLoadingVideo = false }

        if let downloaded = await ExerciseVideoCache.shared.fetch(remote, key: videoURL) {
            localFileURL = downloaded
        }
    }
}

// MARK: - Crossfade frame animator (UIKit-native, no SwiftUI flicker)

private struct CrossfadeFramesView: UIViewRepresentable {
    let urls: [String]

    func makeUIView(context: Context) -> CrossfadeFrameUIView {
        let view = CrossfadeFrameUIView()
        view.contentMode = .scaleAspectFit
        view.load(urls: urls)
        return view
    }

    func updateUIView(_ uiView: CrossfadeFrameUIView, context: Context) {
        uiView.load(urls: urls)
    }

    static func dismantleUIView(_ uiView: CrossfadeFrameUIView, coordinator: ()) {
        uiView.tearDown()
    }
}

private final class CrossfadeFrameUIView: UIView {
    private let imageView = UIImageView()
    private var images: [UIImage] = []
    private var index: Int = 0
    private var timer: Timer?
    private var loadedURLs: [String] = []

    private let holdDuration: TimeInterval = 1.0
    private let crossfadeDuration: TimeInterval = 0.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var contentMode: UIView.ContentMode {
        didSet { imageView.contentMode = contentMode }
    }

    func load(urls: [String]) {
        guard urls != loadedURLs else { return }
        loadedURLs = urls
        tearDown()
        Task { @MainActor [weak self] in
            let fetched = await Self.fetchAll(urls: urls)
            guard let self else { return }
            guard let first = fetched.first else { return }
            self.images = fetched
            self.index = 0
            self.imageView.image = first
            self.imageView.alpha = 0
            UIView.animate(withDuration: 0.35) { self.imageView.alpha = 1 }
            if fetched.count >= 2 { self.startCycling() }
        }
    }

    func tearDown() {
        timer?.invalidate()
        timer = nil
        images = []
        index = 0
    }

    private func startCycling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: holdDuration + crossfadeDuration, repeats: true) { [weak self] _ in
            self?.advance()
        }
    }

    private func advance() {
        guard images.count >= 2 else { return }
        index = (index + 1) % images.count
        let next = images[index]
        UIView.transition(
            with: imageView,
            duration: crossfadeDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: { self.imageView.image = next },
            completion: nil
        )
    }

    private static func fetchAll(urls: [String]) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (i, urlString) in urls.enumerated() {
                group.addTask {
                    guard let url = URL(string: urlString) else { return (i, nil) }
                    if let cached = FrameCache.shared.image(forKey: urlString) { return (i, cached) }
                    do {
                        let (data, response) = try await URLSession.shared.data(from: url)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                              let image = UIImage(data: data) else { return (i, nil) }
                        FrameCache.shared.set(image, forKey: urlString)
                        return (i, image)
                    } catch {
                        return (i, nil)
                    }
                }
            }
            var result: [(Int, UIImage)] = []
            for await (i, img) in group {
                if let img { result.append((i, img)) }
            }
            return result.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
}

// MARK: - In-memory frame cache

private final class FrameCache: @unchecked Sendable {
    nonisolated static let shared = FrameCache()
    // NSCache is thread-safe on its own; access from any context is fine.
    nonisolated(unsafe) private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
    }
    nonisolated func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    nonisolated func set(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

// MARK: - MP4 player layer

private struct LoopingPlayerLayer: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView()
        view.configure(with: fileURL)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.configure(with: fileURL)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }
}

private final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    func configure(with url: URL) {
        if currentURL == url, queuePlayer != nil { return }
        tearDown()
        currentURL = url

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none

        looper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        queuePlayer = player

        player.play()
    }

    func tearDown() {
        queuePlayer?.pause()
        playerLayer.player = nil
        looper = nil
        queuePlayer = nil
        currentURL = nil
    }
}

// MARK: - MP4 cache

actor ExerciseVideoCache {
    static let shared = ExerciseVideoCache()

    private let directory: URL
    private let maxBytes: Int64 = 200 * 1024 * 1024  // 200 MB
    private var inflight: [String: Task<URL?, Never>] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = caches.appendingPathComponent("ExerciseVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    nonisolated func cachedFile(for key: String) -> URL? {
        let url = fileURL(forKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return url
    }

    func fetch(_ remote: URL, key: String) async -> URL? {
        if let existing = inflight[key] { return await existing.value }

        let task = Task<URL?, Never> { [directory, maxBytes] in
            do {
                let (tmpURL, response) = try await URLSession.shared.download(from: remote)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    try? FileManager.default.removeItem(at: tmpURL)
                    return nil
                }
                let dest = directory.appendingPathComponent(Self.hash(key) + ".mp4")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmpURL, to: dest)
                Task.detached { await ExerciseVideoCache.evictIfNeeded(directory: directory, max: maxBytes) }
                return dest
            } catch {
                return nil
            }
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }

    private nonisolated func fileURL(forKey key: String) -> URL {
        directory.appendingPathComponent(Self.hash(key) + ".mp4")
    }

    private static func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static func evictIfNeeded(directory: URL, max: Int64) async {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }

        struct Entry { let url: URL; let size: Int64; let mtime: Date }
        var items: [Entry] = []
        var total: Int64 = 0
        for url in entries {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let mtime = values?.contentModificationDate ?? .distantPast
            items.append(Entry(url: url, size: size, mtime: mtime))
            total += size
        }
        guard total > max else { return }

        items.sort { $0.mtime < $1.mtime }
        for entry in items {
            try? fm.removeItem(at: entry.url)
            total -= entry.size
            if total <= max { break }
        }
    }
}
