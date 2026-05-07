import Foundation
import UIKit
import UserNotifications
import Auth

/// Owns APNs registration + uploads device tokens to Supabase. Tokens are
/// stored per (user_id, token) so multiple devices per user are supported
/// and a user signing out cleanly releases their token.
///
/// Server-side delivery (the JWT-signed APNs HTTP/2 call) lives in the
/// `send_push` Supabase Edge Function; this class just gets the token there.
@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private var lastUploadedToken: String?

    // MARK: - Public API

    /// Ask iOS for permission and register with APNs. Idempotent — calling
    /// repeatedly is safe; already-registered apps just re-trigger the
    /// `didRegisterForRemoteNotifications…` callback.
    func requestAuthorizationAndRegister() async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else {
            #if DEBUG
            print("[Push] User denied notification permission")
            #endif
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Called by the AppDelegate bridge once APNs hands back a token.
    func handleRegistration(deviceToken data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        guard token != lastUploadedToken else { return }
        await upsertToken(token)
        lastUploadedToken = token
    }

    /// Called from the AppDelegate when APNs registration fails (e.g.
    /// running in the simulator without a paired device). Logged in DEBUG;
    /// nothing else to do.
    func handleRegistrationFailure(_ error: Error) {
        #if DEBUG
        print("[Push] APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    /// Drop the user's tokens server-side on sign out.
    func clearTokensForCurrentUser() async {
        guard let userId = await currentUserId() else { return }
        let url = "\(Config.SUPABASE_URL)/rest/v1/push_tokens?user_id=eq.\(userId)"
        guard let u = URL(string: url) else { return }
        var request = URLRequest(url: u)
        request.httpMethod = "DELETE"
        await applyAuthHeaders(&request)
        _ = try? await URLSession.shared.data(for: request)
        lastUploadedToken = nil
    }

    // MARK: - Internals

    /// Insert or refresh the token row. Uses PostgREST upsert via the
    /// `Prefer: resolution=merge-duplicates` header keyed by the unique
    /// (token, platform) constraint.
    private func upsertToken(_ token: String) async {
        guard let userId = await currentUserId() else { return }

        #if DEBUG
        let env = "development"
        #else
        let env = "production"
        #endif

        let body: [String: Any] = [
            "user_id":     userId,
            "token":       token,
            "platform":    "ios",
            "bundle_id":   Bundle.main.bundleIdentifier ?? "",
            "environment": env,
            "updated_at":  ISO8601DateFormatter().string(from: Date())
        ]

        guard let url = URL(string: "\(Config.SUPABASE_URL)/rest/v1/push_tokens"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        await applyAuthHeaders(&request)
        request.httpBody = payload

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            #if DEBUG
            if let http = response as? HTTPURLResponse {
                print("[Push] Token upload status: \(http.statusCode)")
            }
            #endif
        } catch {
            #if DEBUG
            print("[Push] Token upload failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func currentUserId() async -> String? {
        let session = await SupabaseAuthService.shared.currentSession()
        return session?.user.id.uuidString.lowercased()
    }

    private func applyAuthHeaders(_ request: inout URLRequest) async {
        request.setValue(Config.SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        if let session = await SupabaseAuthService.shared.currentSession() {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(Config.SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        }
    }
}
