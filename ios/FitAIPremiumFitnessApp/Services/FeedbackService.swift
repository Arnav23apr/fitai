import Foundation
import UIKit
import Auth

/// Submits user-reported bugs / suggestions / questions to Supabase via the
/// `submit_feedback` RPC (security definer, see `supabase/migrations/005_feedback.sql`).
/// All rows are written to the `user_feedback` table. RLS forbids client reads,
/// so admins access submissions exclusively through the service role.
final class FeedbackService: @unchecked Sendable {
    static let shared = FeedbackService()

    enum Kind: String {
        case bug
        case suggestion
        case question
        case other
    }

    enum SubmitResult {
        case success
        case rateLimited
        case validation(String)
        case failure(String)
    }

    private let baseURL: String = Config.SUPABASE_URL + "/rest/v1"
    private let anonKey: String = Config.SUPABASE_ANON_KEY

    private func authHeaders() async -> [String: String] {
        var token = anonKey
        if let session = await SupabaseAuthService.shared.currentSession() {
            token = session.accessToken
        }
        return [
            "apikey": anonKey,
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
    }

    func submitFeedback(kind: Kind, message: String) async -> SubmitResult {
        guard let url = URL(string: "\(baseURL)/rpc/submit_feedback") else {
            return .failure("invalid_url")
        }

        let body: [String: Any] = [
            "p_kind": kind.rawValue,
            "p_message": message,
            "p_app_version": Self.appVersion,
            "p_ios_version": Self.iosVersion,
            "p_device_model": Self.deviceModel
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = await authHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("no_response")
            }
            if http.statusCode >= 400 {
                return .failure("http_\(http.statusCode)")
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure("decode_failed")
            }
            if let ok = json["ok"] as? Bool, ok {
                return .success
            }
            switch (json["reason"] as? String) ?? "unknown" {
            case "rate_limited":
                return .rateLimited
            case "message_too_short":
                return .validation("Please write at least a few words.")
            case "message_too_long":
                return .validation("Message is too long.")
            case "invalid_kind":
                return .validation("Invalid category.")
            case "unauthenticated":
                return .failure("unauthenticated")
            case let other:
                return .failure(other)
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Device metadata

    private static var appVersion: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static var iosVersion: String {
        UIDevice.current.systemVersion
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let raw = mirror.children.compactMap { $0.value as? Int8 }
            .filter { $0 != 0 }
            .map { String(UnicodeScalar(UInt8($0))) }
            .joined()
        return raw.isEmpty ? UIDevice.current.model : raw
    }
}
