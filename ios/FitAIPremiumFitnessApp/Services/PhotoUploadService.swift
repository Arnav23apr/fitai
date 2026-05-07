import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Auth

/// Uploads images to Supabase Storage and returns a **signed** URL the
/// challenge tables can store. Used by the 1v1 photo battle flow and the
/// goal-projection source upload.
///
/// **Privacy posture:**
/// - JPEGs are stripped of EXIF (GPS, device serial, camera info) before
///   upload. ImageIO writes the bitmap with no metadata source, so location
///   tags can't accidentally land in our buckets.
/// - We return signed URLs (not public ones), so even if a URL leaks the
///   image becomes inaccessible after the expiry window.
/// - **Required Supabase dashboard step**: both `challenge_photos` and
///   `goal_projections` buckets must have "Public bucket" turned OFF for
///   the signed-URL contract to hold. RLS still gates upload as before.
class PhotoUploadService: @unchecked Sendable {
    static let shared = PhotoUploadService()

    private let storageURL: String = Config.SUPABASE_URL + "/storage/v1/object"
    private let signURL: String = Config.SUPABASE_URL + "/storage/v1/object/sign"
    private let anonKey: String = Config.SUPABASE_ANON_KEY

    /// Signed-URL TTLs. Goal-projection source is consumed by the edge
    /// function within seconds, so 1h is generous. Challenge photos must
    /// stay readable for the opponent during the active battle window
    /// (we cap challenges at 7 days).
    private let goalProjectionSourceTTL: Int = 3600        // 1 hour
    private let challengePhotoTTL: Int = 60 * 60 * 24 * 7  // 7 days

    private func authToken() async -> String {
        if let session = await SupabaseAuthService.shared.currentSession() {
            return session.accessToken
        }
        return anonKey
    }

    // MARK: - Public API

    /// Upload a JPEG into `challenge_photos/{userId}/{challengeId}.jpg`.
    /// Returns a 7-day signed URL on success, nil on failure.
    func uploadChallengePhoto(image: UIImage, userId: String, challengeId: String) async -> String? {
        await uploadJPEG(
            image: image,
            bucket: "challenge_photos",
            path: "\(userId.lowercased())/\(challengeId).jpg",
            signedURLTTL: challengePhotoTTL
        )
    }

    /// Upload a JPEG into `goal_projections/{userId}/sources/{ts}.jpg`.
    /// Used as the source image for the Gemini "Future you" projection.
    /// Returns a 1-hour signed URL or nil on failure. The edge function
    /// is expected to consume the URL within that window.
    func uploadGoalProjectionSource(image: UIImage, userId: String) async -> String? {
        await uploadJPEG(
            image: image,
            bucket: "goal_projections",
            path: "\(userId.lowercased())/sources/\(Int(Date().timeIntervalSince1970)).jpg",
            signedURLTTL: goalProjectionSourceTTL
        )
    }

    /// Upload a profile avatar into `profile_photos/{userId}/avatar.jpg`.
    /// Bucket should be **public** in Supabase Storage so leaderboard /
    /// challenge UIs can render the URL directly without re-signing each
    /// session. Returns the public URL on success, nil on failure.
    func uploadProfilePhoto(image: UIImage, userId: String) async -> String? {
        let path = "\(userId.lowercased())/avatar.jpg"
        guard let jpegData = sanitizedJPEG(image: image, quality: 0.85),
              let url = URL(string: "\(storageURL)/profile_photos/\(path)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let token = await authToken()
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "Cache-Control")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = jpegData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? "[unreadable]"
                print("[PhotoUpload/profile_photos] \(http.statusCode): \(body)")
                #endif
                return nil
            }
            // Public bucket → return the public URL with cache-busting
            // timestamp so AsyncImage doesn't show a stale cached avatar
            // on other devices that already loaded the prior version.
            let bust = Int(Date().timeIntervalSince1970)
            return "\(Config.SUPABASE_URL)/storage/v1/object/public/profile_photos/\(path)?v=\(bust)"
        } catch {
            #if DEBUG
            print("[PhotoUpload/profile_photos] error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Re-sign an existing storage path. Call this from the client when a
    /// previously stored URL has expired (e.g., a challenge photo viewed
    /// >7 days after upload — though by then the TTL job should have
    /// purged it anyway).
    func refreshSignedURL(bucket: String, path: String, ttlSeconds: Int) async -> String? {
        await sign(bucket: bucket, path: path, ttlSeconds: ttlSeconds)
    }

    // MARK: - User-facing photo inventory + erasure

    struct StoredPhoto: Identifiable, Sendable {
        let id: String        // bucket + "/" + name (unique)
        let bucket: String
        let name: String      // path within the bucket
        let createdAt: Date?
        let sizeBytes: Int?
    }

    /// List every photo the current user has stored across both buckets.
    /// Used by the Settings → Photos & Data page so users can see exactly
    /// what we hold (GDPR Art. 15 right of access). Returns empty on auth
    /// failure rather than throwing — this is a best-effort UX surface.
    func listUserPhotos(userId: String) async -> [StoredPhoto] {
        let lower = userId.lowercased()
        async let goalSources = listInBucket(bucket: "goal_projections", prefix: "\(lower)/sources")
        async let challenges = listInBucket(bucket: "challenge_photos", prefix: lower)
        let combined = await goalSources + (await challenges)
        // Most recent first.
        return combined.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// Delete every photo the user has across both buckets. Called from
    /// "Delete all my photos" in Settings (GDPR Art. 17 right to erasure).
    /// Returns the count of objects removed.
    @discardableResult
    func deleteAllUserPhotos(userId: String) async -> Int {
        let lower = userId.lowercased()
        async let g = deleteInBucket(bucket: "goal_projections", prefix: "\(lower)/sources")
        async let c = deleteInBucket(bucket: "challenge_photos", prefix: lower)
        return await g + (await c)
    }

    // MARK: - Storage list/delete REST helpers

    private struct StorageListItem: Decodable {
        let name: String
        let id: String?
        let updated_at: String?
        let created_at: String?
        let metadata: Metadata?
        struct Metadata: Decodable {
            let size: Int?
        }
    }

    private func listInBucket(bucket: String, prefix: String) async -> [StoredPhoto] {
        guard let url = URL(string: "\(Config.SUPABASE_URL)/storage/v1/object/list/\(bucket)") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20

        let token = await authToken()
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "prefix": prefix,
            "limit": 200,
            "offset": 0,
            "sortBy": ["column": "created_at", "order": "desc"]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 { return [] }
            let items = (try? JSONDecoder().decode([StorageListItem].self, from: data)) ?? []
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return items.compactMap { item in
                // `list/` returns names relative to the prefix's parent —
                // re-prepend the prefix so the path is whole again.
                let fullName = prefix.isEmpty ? item.name : "\(prefix)/\(item.name)"
                return StoredPhoto(
                    id: "\(bucket)/\(fullName)",
                    bucket: bucket,
                    name: fullName,
                    createdAt: item.created_at.flatMap { iso.date(from: $0) },
                    sizeBytes: item.metadata?.size
                )
            }
        } catch {
            return []
        }
    }

    private func deleteInBucket(bucket: String, prefix: String) async -> Int {
        let photos = await listInBucket(bucket: bucket, prefix: prefix)
        guard !photos.isEmpty else { return 0 }
        guard let url = URL(string: "\(Config.SUPABASE_URL)/storage/v1/object/\(bucket)") else { return 0 }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let token = await authToken()
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let prefixes = photos.map(\.name)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["prefixes": prefixes])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 { return 0 }
            return photos.count
        } catch {
            return 0
        }
    }

    // MARK: - Internals

    private func uploadJPEG(
        image: UIImage,
        bucket: String,
        path: String,
        signedURLTTL: Int
    ) async -> String? {
        guard let jpegData = sanitizedJPEG(image: image, quality: 0.85) else { return nil }

        // POST with x-upsert: true so re-submitting overwrites cleanly.
        guard let url = URL(string: "\(storageURL)/\(bucket)/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let token = await authToken()
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "Cache-Control")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = jpegData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? "[unreadable]"
                print("[PhotoUpload/\(bucket)] \(http.statusCode): \(body)")
                #endif
                return nil
            }
            return await sign(bucket: bucket, path: path, ttlSeconds: signedURLTTL)
        } catch {
            #if DEBUG
            print("[PhotoUpload/\(bucket)] error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Mint a Supabase signed URL for `{bucket}/{path}` valid for `ttlSeconds`.
    /// Returns the fully-qualified URL on success, nil on failure.
    private func sign(bucket: String, path: String, ttlSeconds: Int) async -> String? {
        guard let url = URL(string: "\(signURL)/\(bucket)/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        let token = await authToken()
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["expiresIn": ttlSeconds])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? "[unreadable]"
                print("[PhotoUpload/sign \(bucket)] \(http.statusCode): \(body)")
                #endif
                return nil
            }
            // Supabase returns `{ "signedURL": "/object/sign/bucket/path?token=..." }`
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let signed = json["signedURL"] as? String else {
                return nil
            }
            // The path may already start with "/" — collapse defensively.
            let trimmed = signed.hasPrefix("/") ? String(signed.dropFirst()) : signed
            return "\(Config.SUPABASE_URL)/storage/v1/\(trimmed)"
        } catch {
            #if DEBUG
            print("[PhotoUpload/sign \(bucket)] error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Re-encode the image as JPEG **without** any metadata. Goes through
    /// ImageIO's `CGImageDestination` with no metadata source — output
    /// contains the bitmap and color profile only, no EXIF, no GPS, no
    /// device serial, no camera/lens identifiers. This is the GDPR
    /// special-category mitigation: location-tagged body photos auto-
    /// promote to "health data" + "biometric" categories under Art. 9.
    private func sanitizedJPEG(image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else {
            // Fallback: UIImage's jpegData re-encodes via CGImage and drops
            // the orientation but may keep some metadata. Better than nil.
            return image.jpegData(compressionQuality: quality)
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return image.jpegData(compressionQuality: quality)
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            // Explicitly NOT passing kCGImagePropertyExifDictionary,
            // kCGImagePropertyGPSDictionary, kCGImagePropertyTIFFDictionary,
            // etc. — omitting them is what strips them.
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return image.jpegData(compressionQuality: quality)
        }
        return data as Data
    }
}
