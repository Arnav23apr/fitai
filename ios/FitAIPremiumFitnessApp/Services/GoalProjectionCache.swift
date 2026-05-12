import Foundation
import UIKit

/// On-disk cache for the AI-generated goal physique projection.
///
/// The server stores the projection URL on the user profile (`goal_projection_url`),
/// but the bytes live on Supabase Storage and SwiftUI's `AsyncImage` re-fetches them
/// every load. Any transient CDN/network failure produces the "Couldn't load your
/// projection" placeholder — frustrating because the 90-day cooldown blocks the
/// obvious workaround (regenerate).
///
/// This cache writes the bytes to `Caches/goal_projection_{userId}.jpg` after the
/// first successful fetch, with a sidecar `.url` file remembering which URL the
/// bytes came from. On subsequent loads the card prefers cached bytes; the URL
/// mismatch check means a fresh regeneration invalidates the stale image.
enum GoalProjectionCache {

    private static var cachesDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    private static func imageURL(for userId: String) -> URL? {
        cachesDir?.appendingPathComponent("goal_projection_\(userId).jpg")
    }

    private static func sidecarURL(for userId: String) -> URL? {
        cachesDir?.appendingPathComponent("goal_projection_\(userId).url")
    }

    /// Separate file for the Scan tab's locally-generated "90-Day
    /// Transformation". The Profile card prefers this over the
    /// server-side projection so the user sees the same image in both
    /// places without an extra server round-trip (or fighting the
    /// 90-day cooldown).
    private static func scanTransformationURL(for userId: String) -> URL? {
        cachesDir?.appendingPathComponent("scan_transformation_\(userId).jpg")
    }

    /// Returns cached bytes if the cached URL matches the currently-stored projection URL.
    /// Mismatch (or missing sidecar) means a newer regeneration invalidated this entry.
    static func loadImage(userId: String, expectedURL: String) -> UIImage? {
        guard let imgURL = imageURL(for: userId),
              let sideURL = sidecarURL(for: userId),
              FileManager.default.fileExists(atPath: imgURL.path),
              let cachedURL = try? String(contentsOf: sideURL, encoding: .utf8),
              cachedURL == expectedURL,
              let data = try? Data(contentsOf: imgURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    /// Persist freshly-fetched bytes alongside the URL they came from.
    static func save(data: Data, userId: String, url: String) {
        guard let imgURL = imageURL(for: userId),
              let sideURL = sidecarURL(for: userId) else { return }
        try? data.write(to: imgURL, options: .atomic)
        try? url.write(to: sideURL, atomically: true, encoding: .utf8)
    }

    /// Download bytes for `url` and store them. Returns the decoded image on success.
    @discardableResult
    static func fetchAndStore(url: String, userId: String) async -> UIImage? {
        guard let u = URL(string: url) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: u)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            save(data: data, userId: userId, url: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    /// Wipe cached bytes for a user (e.g. on logout / account delete).
    static func clear(userId: String) {
        if let imgURL = imageURL(for: userId) {
            try? FileManager.default.removeItem(at: imgURL)
        }
        if let sideURL = sidecarURL(for: userId) {
            try? FileManager.default.removeItem(at: sideURL)
        }
        clearScanTransformation(userId: userId)
    }

    // MARK: - Scan-tab transformation bridge

    /// Persist the latest Scan-tab "90-Day Transformation" so the
    /// Profile card can display it without going through Supabase
    /// Storage. Overwrites any prior local transformation for this user.
    static func saveScanTransformation(image: UIImage, userId: String) {
        guard let url = scanTransformationURL(for: userId),
              let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Returns the user's locally-stored Scan transformation if present.
    static func loadScanTransformation(userId: String) -> UIImage? {
        guard let url = scanTransformationURL(for: userId),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    /// Synchronous existence check used by views to decide whether the
    /// "Future you" card should render at all.
    static func hasScanTransformation(userId: String) -> Bool {
        guard let url = scanTransformationURL(for: userId) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Wipe just the scan transformation (e.g. when a fresh server-side
    /// projection supersedes it).
    static func clearScanTransformation(userId: String) {
        if let url = scanTransformationURL(for: userId) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

extension Notification.Name {
    /// Posted by `ScanViewModel.generateTransformation` after the image
    /// has been saved to the local cache. Observed by
    /// `GoalProjectionCard` so the Profile card refreshes without
    /// requiring a tab-switch round-trip.
    static let scanTransformationGenerated = Notification.Name("FitAI.scanTransformationGenerated")
}
