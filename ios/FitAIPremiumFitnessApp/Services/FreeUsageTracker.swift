import Foundation

/// Per-week free-tier usage counter for AI-powered logging features
/// (voice + photo). Pro users bypass entirely; free users get N uses per
/// feature per ISO week before the paywall fires.
///
/// Storage: UserDefaults — small enough to not need its own persistence.
/// Reset key: ISO year-week identifier; rolls over automatically.
nonisolated final class FreeUsageTracker: Sendable {
    static let shared = FreeUsageTracker()

    enum Feature: String {
        case voice
        case photo
    }

    /// Free users get this many uses per ISO week.
    static let freeWeeklyCap: Int = 5

    private init() {}

    // MARK: - Public

    /// Whether this feature can be used right now without hitting the
    /// paywall. Pro users always pass.
    func canUse(_ feature: Feature, isPremium: Bool) -> Bool {
        guard !isPremium else { return true }
        return remaining(for: feature) > 0
    }

    /// Record a successful use. Returns the remaining count (post-record)
    /// so callers can show "3 of 5 free uses left this week."
    @discardableResult
    func record(_ feature: Feature, isPremium: Bool) -> Int {
        guard !isPremium else { return Int.max }
        let key = countKey(for: feature)
        rotateIfNeeded(feature: feature)
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
        return max(0, Self.freeWeeklyCap - (current + 1))
    }

    /// Reads the remaining count for the current week. Pro users see ∞.
    func remaining(for feature: Feature) -> Int {
        rotateIfNeeded(feature: feature)
        let used = UserDefaults.standard.integer(forKey: countKey(for: feature))
        return max(0, Self.freeWeeklyCap - used)
    }

    // MARK: - Storage

    private func countKey(for feature: Feature) -> String {
        "freeUsage.\(feature.rawValue).count"
    }

    private func weekKey(for feature: Feature) -> String {
        "freeUsage.\(feature.rawValue).week"
    }

    /// Resets the counter when the ISO week stamp changes. Cheap, runs on
    /// every read/write — no scheduling required.
    private func rotateIfNeeded(feature: Feature) {
        let stored = UserDefaults.standard.string(forKey: weekKey(for: feature)) ?? ""
        let current = Self.currentWeekStamp()
        if stored != current {
            UserDefaults.standard.set(0, forKey: countKey(for: feature))
            UserDefaults.standard.set(current, forKey: weekKey(for: feature))
        }
    }

    /// "2026-W19" style identifier — changes on Monday, same scheme across
    /// timezones since we use the user's calendar.
    private static func currentWeekStamp() -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }
}
