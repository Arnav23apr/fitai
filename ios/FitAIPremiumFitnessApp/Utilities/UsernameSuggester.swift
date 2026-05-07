import Foundation

/// Generates fitness-themed username suggestions for the onboarding step
/// and the backfill modal. Pure logic, no I/O — caller checks availability
/// against Supabase via SupabaseSyncService.isUsernameAvailable.
///
/// Output rules: lowercase, 3-20 chars, allowed `[a-z0-9_]` only.
/// Strategy: pick a fitness adjective/noun + the user's first-name root
/// from email or display name + optional collision-buster digits.
enum UsernameSuggester {

    /// Fitness-coded words that read clean as a prefix or full handle.
    /// Skewed male/lifter on purpose — the audience is gym-going men.
    private static let prefixes: [String] = [
        "iron", "steel", "forge", "lift", "rep", "squat", "pump",
        "plate", "grind", "apex", "set", "pr", "beast", "raw"
    ]

    /// Builds 7 candidate handles from a seed (typically the user's email
    /// local-part or first name). Caller picks the first one available.
    static func suggestions(seed: String) -> [String] {
        let root = sanitizedRoot(seed)
        var out: [String] = []

        // Bare seed first — what the user would naturally pick.
        if root.count >= 3 { out.append(root) }

        // Prefix + root combos (`ironarnav`, `liftarnav`, etc.)
        for p in ["iron", "lift", "beast", "forge", "rep"] where root.count >= 2 {
            out.append("\(p)\(root)")
        }

        // Root + suffix combos (`arnavmode`, `arnavpr`)
        if root.count >= 3 {
            out.append("\(root)mode")
            out.append("\(root)pr")
        }

        // Numbered fallback if root is too short or empty.
        let randomDigits = String(format: "%04d", Int.random(in: 1000...9999))
        out.append("\(prefixes.randomElement() ?? "lift")\(randomDigits)")

        // Filter: 3-20 chars, allowed chars, dedupe, max 7 suggestions.
        return Array(
            out.compactMap { normalize($0) }
               .filter { isValid($0) }
               .reduce(into: [String]()) { acc, s in
                   if !acc.contains(s) { acc.append(s) }
               }
               .prefix(7)
        )
    }

    // MARK: - Validation (also used by the picker view's inline checker)

    static func isValid(_ candidate: String) -> Bool {
        let s = candidate
        guard s.count >= 3, s.count <= 20 else { return false }
        // Lowercase a-z, digits, underscore, period.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        if s.unicodeScalars.contains(where: { !allowed.contains($0) }) { return false }
        // No leading/trailing/consecutive separators.
        if s.first == "_" || s.first == "." { return false }
        if s.last == "_"  || s.last == "."  { return false }
        if s.contains("__") || s.contains("..") || s.contains("._") || s.contains("_.") { return false }
        if reservedHandles.contains(s) { return false }
        if profanityHits(s) { return false }
        return true
    }

    /// Localized validation message for the picker view's red text below
    /// the field. Returns nil when the candidate is valid (per format —
    /// availability is a separate network check).
    static func validationError(_ candidate: String) -> String? {
        let s = candidate
        if s.isEmpty { return nil } // don't yell at empty input
        if s.count < 3 { return "At least 3 characters." }
        if s.count > 20 { return "Max 20 characters." }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        if s.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Only lowercase letters, numbers, _ and ."
        }
        if s.first == "_" || s.first == "." || s.last == "_" || s.last == "." {
            return "Can't start or end with _ or ."
        }
        if s.contains("__") || s.contains("..") || s.contains("._") || s.contains("_.") {
            return "No consecutive _ or ."
        }
        if reservedHandles.contains(s) { return "That handle is reserved." }
        if profanityHits(s) { return "Pick something else." }
        return nil
    }

    // MARK: - Internals

    private static func normalize(_ s: String) -> String? {
        let lowered = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else { return nil }
        // Strip anything not allowed.
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")
        let filtered = String(lowered.filter { allowed.contains($0) })
        return filtered.isEmpty ? nil : filtered
    }

    /// Pull a usable seed from a name or email. "jane.doe@example.com"
    /// becomes "arnav", "Arnav Kumar" becomes "arnav", "" returns "lifter".
    private static func sanitizedRoot(_ seed: String) -> String {
        var s = seed
        if let at = s.firstIndex(of: "@") { s = String(s[..<at]) } // drop email domain
        // Drop everything after `+`, `.`, ` `, `_` to keep the first name only.
        for sep in ["+", ".", " ", "_", "-"] {
            if let r = s.range(of: sep) { s = String(s[..<r.lowerBound]) }
        }
        let normalized = normalize(s) ?? ""
        return normalized.isEmpty ? "lifter" : normalized
    }

    /// Reserved handles — admin/support/system terms + super-short variants
    /// we want to keep for ops/marketing.
    private static let reservedHandles: Set<String> = [
        "admin", "root", "support", "fitai", "official", "help", "system",
        "moderator", "mod", "api", "www", "null", "undefined", "test",
        "staff", "team", "user", "users", "me", "you", "anon", "anonymous"
    ]

    /// Tiny profanity guard — blocks the obvious offensive substrings.
    /// Keep this intentionally minimal; expand only with user reports.
    private static let profanityFragments: [String] = [
        "fuck", "shit", "cunt", "nigg", "fag", "rape", "nazi", "kkk",
        "retard", "tranny", "spic", "kike", "chink"
    ]

    private static func profanityHits(_ s: String) -> Bool {
        profanityFragments.contains(where: { s.contains($0) })
    }
}
