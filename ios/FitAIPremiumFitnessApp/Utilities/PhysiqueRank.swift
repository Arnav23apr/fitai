import SwiftUI

/// Physique tier derived from the user's latest scan score and gender.
/// 7 buckets from "it's over" to "leave some girls for us bro" (male) /
/// "U single?" (female), with gendered variants from 5-6 upward.
///
/// Earlier versions used PSL face-rating terms (HTN/HTB) and then
/// physique-formal vocab (Sedentary/Chad/GigaChad). This pass leans
/// into 2026 gym-TikTok meme culture (mogger, muscle mommy, gym crush).
///
/// `rawValue` is plain text persisted to Supabase. `displayName` is
/// the user-facing label including emoji.
///
/// Used as the value of `UserProfile.tier`. Old saved tier strings
/// (Sedentary, Chad, etc.) decode to `.unranked` and self-heal on the
/// next scan when `AppState.updateTier()` runs.
enum PhysiqueRank: String, CaseIterable, Sendable {
    // <2 — shared
    case itsOver         = "it's over"

    // 2-4 — shared
    case workHarder      = "Gotta work harder"

    // 4-5 — shared
    case gettingThere    = "Getting there"

    // 5-6 — gendered
    case gymBro          = "gym bro"
    case muscleMommy     = "muscle mommy"

    // 6-7 — gendered
    case mogger          = "mogger"
    case gymBaddie       = "gym baddie"

    // 7-8 — gendered
    case nattyBro        = "You natty bro?"
    case gymCrush        = "gym crush"

    // 8+ — gendered (peak meme tier)
    case leaveSome       = "leave some girls for us bro"
    case uSingle         = "U single?"

    // No scan yet
    case unranked        = "Unranked"

    // MARK: - Mapping

    /// Returns the physique rank for a given scan score and gender string.
    /// Pass the raw `profile.latestScore` (0–10) and `profile.gender`.
    /// `nil` or zero score → `.unranked`.
    static func rank(score: Double?, gender: String) -> PhysiqueRank {
        guard let s = score, s > 0 else { return .unranked }
        let g = gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"

        switch s {
        case ..<2.0:  return .itsOver
        case ..<4.0:  return .workHarder
        case ..<5.0:  return .gettingThere
        case ..<6.0:  return isFemale ? .muscleMommy : .gymBro
        case ..<7.0:  return isFemale ? .gymBaddie   : .mogger
        case ..<8.0:  return isFemale ? .gymCrush    : .nattyBro
        default:      return isFemale ? .uSingle     : .leaveSome
        }
    }

    /// Build from the raw stored tier string (round-trips
    /// `profile.tier` ↔ `PhysiqueRank`).
    static func from(tier: String) -> PhysiqueRank {
        PhysiqueRank(rawValue: tier) ?? .unranked
    }

    // MARK: - UI

    /// User-facing label without emoji. Pair with `emoji` for rendering;
    /// applying a bold weight to a Text that contains an emoji can hit
    /// font-fallback bugs that show the emoji as a missing glyph.
    var label: String {
        switch self {
        case .unranked:     return "Unranked"
        case .itsOver:      return "it's over"
        case .workHarder:   return "Gotta work harder"
        case .gettingThere: return "Getting there"
        case .gymBro:       return "gym bro"
        case .muscleMommy:  return "muscle mommy"
        case .mogger:       return "mogger"
        case .gymBaddie:    return "gym baddie"
        case .nattyBro:     return "You natty bro?"
        case .gymCrush:     return "gym crush"
        case .leaveSome:    return "leave some girls for us bro"
        case .uSingle:      return "U single?"
        }
    }

    /// Trailing emoji for this tier. Empty for `.unranked`. The 8+ male
    /// tier also has a leading 👑 — see `leadingEmoji`.
    var emoji: String {
        switch self {
        case .unranked:     return ""
        case .itsOver:      return "💀"
        case .workHarder:   return "😤"
        case .gettingThere: return "📈"
        case .gymBro:       return "💪"
        case .muscleMommy:  return "🦾"
        case .mogger:       return "🗿"
        case .gymBaddie:    return "🔥"
        case .nattyBro:     return "👀"
        case .gymCrush:     return "💖"
        case .leaveSome:    return "😭"
        case .uSingle:      return "🥹"
        }
    }

    /// Optional leading emoji (renders before the label). Used only by
    /// the apex male tier so the bookended 👑…😭 reads as "king + cope".
    var leadingEmoji: String {
        self == .leaveSome ? "👑" : ""
    }

    /// User-facing label including emoji. Convenience for places that
    /// want a single string. Prefer rendering `label` and `emoji` as
    /// separate Text views in HStack — that avoids the bold-font emoji
    /// rendering bug.
    var displayName: String {
        let lead = leadingEmoji.isEmpty ? "" : "\(leadingEmoji) "
        let trail = emoji.isEmpty ? "" : " \(emoji)"
        return "\(lead)\(label)\(trail)"
    }

    /// Numeric ordering 0 (worst) → 6 (best). Used for sorting/comparisons.
    var ordinal: Int {
        switch self {
        case .unranked:                     return -1
        case .itsOver:                      return 0
        case .workHarder:                   return 1
        case .gettingThere:                 return 2
        case .gymBro, .muscleMommy:         return 3
        case .mogger, .gymBaddie:           return 4
        case .nattyBro, .gymCrush:          return 5
        case .leaveSome, .uSingle:          return 6
        }
    }

    /// Primary brand color for this tier. Progression: gray → orange →
    /// yellow → green → cyan → gold → purple.
    var color: Color {
        switch self {
        case .unranked:
            return Color(red: 0.50, green: 0.50, blue: 0.55)
        case .itsOver:
            return Color(red: 0.40, green: 0.40, blue: 0.45)
        case .workHarder:
            return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .gettingThere:
            return Color(red: 0.95, green: 0.80, blue: 0.20)
        case .gymBro, .muscleMommy:
            return Color(red: 0.45, green: 0.80, blue: 0.40)
        case .mogger, .gymBaddie:
            return Color(red: 0.20, green: 0.65, blue: 1.00)
        case .nattyBro, .gymCrush:
            return Color(red: 1.00, green: 0.78, blue: 0.20)
        case .leaveSome, .uSingle:
            return Color(red: 0.80, green: 0.40, blue: 1.00)
        }
    }

    /// Secondary color for gradient effects.
    var secondaryColor: Color {
        switch self {
        case .unranked:
            return Color(red: 0.30, green: 0.30, blue: 0.35)
        case .itsOver:
            return Color(red: 0.22, green: 0.22, blue: 0.25)
        case .workHarder:
            return Color(red: 0.75, green: 0.35, blue: 0.10)
        case .gettingThere:
            return Color(red: 0.75, green: 0.55, blue: 0.10)
        case .gymBro, .muscleMommy:
            return Color(red: 0.25, green: 0.60, blue: 0.20)
        case .mogger, .gymBaddie:
            return Color(red: 0.10, green: 0.45, blue: 0.85)
        case .nattyBro, .gymCrush:
            return Color(red: 0.85, green: 0.55, blue: 0.10)
        case .leaveSome, .uSingle:
            return Color(red: 0.50, green: 0.20, blue: 0.85)
        }
    }

    /// SF Symbol icon for this rank.
    var icon: String {
        switch self {
        case .unranked:                     return "questionmark.circle"
        case .itsOver:                      return "minus.circle"
        case .workHarder:                   return "chart.line.downtrend.xyaxis"
        case .gettingThere:                 return "circle.fill"
        case .gymBro, .muscleMommy:         return "arrow.up.circle.fill"
        case .mogger, .gymBaddie:           return "bolt.fill"
        case .nattyBro, .gymCrush:          return "crown.fill"
        case .leaveSome, .uSingle:          return "diamond.fill"
        }
    }
}
