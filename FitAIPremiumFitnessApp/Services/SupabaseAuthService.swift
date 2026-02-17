import Foundation
import Auth

let supabaseAuth = AuthClient(
    url: URL(string: "\(Config.SUPABASE_URL)/auth/v1")!,
    headers: ["apikey": Config.SUPABASE_ANON_KEY],
    flowType: .pkce,
    redirectToURL: URL(string: "fitaipremium://auth-callback"),
    localStorage: AuthClient.Configuration.defaultLocalStorage
)

class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    func signInWithGoogle() async throws -> Session {
        try await supabaseAuth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "fitaipremium://auth-callback")
        )
    }

    func signOut() async throws {
        try await supabaseAuth.signOut()
    }

    func currentSession() async -> Session? {
        try? await supabaseAuth.session
    }
}
