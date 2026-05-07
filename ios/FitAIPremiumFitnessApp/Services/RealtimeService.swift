import Foundation
import Auth

#if canImport(Realtime)
import Realtime

/// Single shared Realtime client for the app. We don't use the umbrella
/// `Supabase` package (only `Auth` is linked), so the Realtime client is
/// constructed standalone here against the same project URL + anon key.
///
/// Auth: the closure passed as `accessToken` is invoked by the SDK on every
/// subscribe / re-subscribe, so it always sends the current user's JWT —
/// no manual `setAuth(...)` calls needed when sessions refresh.
///
/// Wrapped in `#if canImport(Realtime)` so the app builds even when the
/// Realtime SPM product hasn't been linked to the target yet — start/stop
/// in FriendViewModel become no-ops in that case (no real-time updates,
/// but no compile failure either).
@MainActor
final class RealtimeService {
    static let shared = RealtimeService()

    let client: RealtimeClientV2

    private init() {
        let baseURL = Config.SUPABASE_URL
        // Realtime needs the websocket-style URL: /realtime/v1
        let realtimeURL = URL(string: "\(baseURL)/realtime/v1")!
        client = RealtimeClientV2(
            url: realtimeURL,
            options: RealtimeClientOptions(
                headers: ["apikey": Config.SUPABASE_ANON_KEY],
                accessToken: {
                    let session = await SupabaseAuthService.shared.currentSession()
                    return session?.accessToken
                }
            )
        )
    }
}
#endif
