import Foundation
import Auth

/// Calls the `generate_goal_projection` Supabase Edge Function which runs
/// Gemini 2.5 Flash Image ("Nano Banana") on the user's most recent scan
/// photo, uploads the AI rendering to Storage, and patches the profile's
/// `goal_projection_url`. The iOS side then renders that URL from the
/// `GoalProjectionCard` in PlanPreview / Profile / pre-cancel sheet.
final class GoalProjectionService: @unchecked Sendable {
    static let shared = GoalProjectionService()

    private let baseURL: String = Config.SUPABASE_URL
    private let anonKey: String = Config.SUPABASE_ANON_KEY

    enum Result {
        case success(url: String)
        /// Server-side cooldown still active. `daysLeft` is calendar days
        /// until the next allowed regeneration.
        case cooldown(daysLeft: Int)
        case noScan
        case failure(String)
    }

    /// Generate / regenerate the projection. Pass the public URL of a
    /// previously-uploaded source image — typically the user's most recent
    /// front body-scan photo.
    func generate(sourceImageURL: String) async -> Result {
        guard let url = URL(string: "\(baseURL)/functions/v1/generate_goal_projection") else {
            return .failure("invalid_url")
        }

        guard let session = await SupabaseAuthService.shared.currentSession() else {
            return .failure("unauthenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["source_image_url": sourceImageURL]
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("no_response")
            }

            // Try to decode JSON either way — soft failures come back as 200
            // with `{ ok: false, reason: ... }`.
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            if http.statusCode >= 400 {
                let reason = (json["reason"] as? String) ?? "http_\(http.statusCode)"
                return .failure(reason)
            }

            if let ok = json["ok"] as? Bool, ok, let urlStr = json["url"] as? String {
                return .success(url: urlStr)
            }

            switch json["reason"] as? String {
            case "cooldown":
                let days = json["days_left"] as? Int ?? 0
                return .cooldown(daysLeft: days)
            case "couldnt_fetch_source", "missing_source_image_url":
                return .noScan
            case let other?:
                return .failure(other)
            default:
                return .failure("unknown")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
