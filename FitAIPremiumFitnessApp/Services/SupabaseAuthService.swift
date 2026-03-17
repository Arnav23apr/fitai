import Foundation
import Auth
import UIKit
import AuthenticationServices

let supabaseAuth = AuthClient(
    url: URL(string: "\(Config.SUPABASE_URL)/auth/v1")!,
    headers: ["apikey": Config.SUPABASE_ANON_KEY],
    flowType: .pkce,
    redirectToURL: URL(string: "fitaipremium://auth-callback"),
    localStorage: AuthClient.Configuration.defaultLocalStorage
)

class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        try await supabaseAuth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }

    @MainActor
    func signInWithGoogle() async throws -> Session {
        // Use the real key window as the ASWebAuthenticationSession anchor.
        // The SDK default (a bare UIWindow() with no scene) crashes on start().
        let anchor: UIWindow? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.keyWindow }
            .first

        return try await supabaseAuth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "fitaipremium://auth-callback"),
            configure: { (session: ASWebAuthenticationSession) in
                if let anchor = anchor as? ASWebAuthenticationPresentationContextProviding {
                    session.presentationContextProvider = anchor
                }
            }
        )
    }

    func signUpWithEmail(email: String, password: String) async throws -> Session {
        let result = try await supabaseAuth.signUp(email: email, password: password)
        guard let session = result.session else {
            throw AuthError.emailConfirmationRequired
        }
        return session
    }

    func signInWithEmail(email: String, password: String) async throws -> Session {
        try await supabaseAuth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await supabaseAuth.signOut()
    }

    func currentSession() async -> Session? {
        try? await supabaseAuth.session
    }
}

nonisolated enum AuthError: LocalizedError, Sendable {
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "Please check your email to confirm your account."
        }
    }
}
