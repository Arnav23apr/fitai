import Foundation

/// Single source of truth for the hosted privacy policy + terms URLs.
/// Bumped here when the GitHub Pages URL or custom domain changes; every
/// in-app legal link reads from this enum so the policy never falls out
/// of sync across views.
///
/// Currently hosted via GitHub Pages (`docs/` folder, main branch) at the
/// repo at github.com/Arnav23apr/fitai. Once a custom domain (e.g.
/// fitai.health) is wired into Pages, swap the base here.
enum LegalLinks {
    /// Update this if the repo is renamed or moves to a custom domain.
    static let baseURL = "https://arnav23apr.github.io/fitai"

    static var privacy: URL {
        URL(string: "\(baseURL)/privacy/")!
    }

    static var terms: URL {
        URL(string: "\(baseURL)/terms/")!
    }

    static var home: URL {
        URL(string: "\(baseURL)/")!
    }
}
