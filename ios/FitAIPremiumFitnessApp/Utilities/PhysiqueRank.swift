import SwiftUI

/// Physique tier derived from the user's latest scan score and gender.
/// Maps the 0-10 overall score onto a looksmaxxing-style ladder.
/// Used as the value of `UserProfile.tier`.
enum PhysiqueRank: String, CaseIterable, Sendable {
    // Bottom tier — gender-shared
    case sub2       = "Sub-2"
    case sub3       = "Sub-3"

    // Lower tier — gender-branched
    case truecel    = "Truecel"
    case femcel     = "Femcel"

    // Below average — gender-branched
    case incelTier  = "Incel-tier"
    case belowAvg   = "Below Avg"

    // Average — gender-branched
    case normie     = "Normie"
    case becky      = "Becky"

    // Above average — gender-branched
    case htn        = "HTN"
    case htb        = "HTB"

    // Top normie / chad-light — gender-branched
    case chadlite   = "Chadlite"
    case stacylite  = "Stacylite"

    // Top tier — gender-branched
    case chad       = "Chad"
    case stacy      = "Stacy"

    // Apex — gender-branched
    case gigaChad   = "GigaChad"
    case gigaStacy  = "GigaStacy"

    // No scan yet
    case unranked   = "Unranked"

    // MARK: - Mapping

    /// Returns the physique rank for a given scan score and gender string.
    /// Pass the raw `profile.latestScore` (0–10) and `profile.gender`.
    /// `nil` score → `.unranked`.
    static func rank(score: Double?, gender: String) -> PhysiqueRank {
        guard let s = score, s > 0 else { return .unranked }
        let g = gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"

        switch s {
        case ..<2.0:  return .sub2
        case ..<3.0:  return .sub3
        case ..<4.0:  return isFemale ? .femcel    : .truecel
        case ..<5.0:  return isFemale ? .belowAvg  : .incelTier
        case ..<6.0:  return isFemale ? .becky     : .normie
        case ..<7.0:  return isFemale ? .htb       : .htn
        case ..<8.0:  return isFemale ? .stacylite : .chadlite
        case ..<9.0:  return isFemale ? .stacy     : .chad
        default:      return isFemale ? .gigaStacy : .gigaChad
        }
    }

    /// Build from the raw stored tier string (round-trips
    /// `profile.tier` ↔ `PhysiqueRank`).
    static func from(tier: String) -> PhysiqueRank {
        PhysiqueRank(rawValue: tier) ?? .unranked
    }

    // MARK: - UI

    /// Numeric ordering 0 (worst) → 9 (best). Used for sorting/comparisons.
    var ordinal: Int {
        switch self {
        case .unranked:                      return -1
        case .sub2:                          return 0
        case .sub3:                          return 1
        case .truecel, .femcel:              return 2
        case .incelTier, .belowAvg:          return 3
        case .normie, .becky:                return 4
        case .htn, .htb:                     return 5
        case .chadlite, .stacylite:          return 6
        case .chad, .stacy:                  return 7
        case .gigaChad, .gigaStacy:          return 8
        }
    }

    /// Primary brand color for this tier.
    var color: Color {
        switch self {
        case .unranked:
            return Color(red: 0.50, green: 0.50, blue: 0.55)
        case .sub2:
            return Color(red: 0.35, green: 0.35, blue: 0.40)
        case .sub3:
            return Color(red: 0.55, green: 0.30, blue: 0.30)
        case .truecel, .femcel:
            return Color(red: 0.85, green: 0.30, blue: 0.30)
        case .incelTier, .belowAvg:
            return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .normie, .becky:
            return Color(red: 0.95, green: 0.80, blue: 0.20)
        case .htn, .htb:
            return Color(red: 0.30, green: 0.75, blue: 0.55)
        case .chadlite, .stacylite:
            return Color(red: 0.30, green: 0.65, blue: 1.00)
        case .chad, .stacy:
            return Color(red: 1.00, green: 0.78, blue: 0.20)
        case .gigaChad, .gigaStacy:
            return Color(red: 0.80, green: 0.40, blue: 1.00)
        }
    }

    /// Secondary color for gradient effects.
    var secondaryColor: Color {
        switch self {
        case .unranked:
            return Color(red: 0.30, green: 0.30, blue: 0.35)
        case .sub2:
            return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .sub3:
            return Color(red: 0.35, green: 0.18, blue: 0.18)
        case .truecel, .femcel:
            return Color(red: 0.55, green: 0.15, blue: 0.15)
        case .incelTier, .belowAvg:
            return Color(red: 0.75, green: 0.35, blue: 0.10)
        case .normie, .becky:
            return Color(red: 0.75, green: 0.55, blue: 0.10)
        case .htn, .htb:
            return Color(red: 0.10, green: 0.55, blue: 0.40)
        case .chadlite, .stacylite:
            return Color(red: 0.15, green: 0.40, blue: 0.85)
        case .chad, .stacy:
            return Color(red: 0.85, green: 0.55, blue: 0.10)
        case .gigaChad, .gigaStacy:
            return Color(red: 0.50, green: 0.20, blue: 0.85)
        }
    }

    /// SF Symbol icon for this rank.
    var icon: String {
        switch self {
        case .unranked:                      return "questionmark.circle"
        case .sub2:                          return "minus.circle"
        case .sub3:                          return "exclamationmark.triangle"
        case .truecel, .femcel:              return "arrow.down.circle"
        case .incelTier, .belowAvg:          return "chart.line.downtrend.xyaxis"
        case .normie, .becky:                return "person.fill"
        case .htn, .htb:                     return "arrow.up.circle"
        case .chadlite, .stacylite:          return "star.fill"
        case .chad, .stacy:                  return "crown.fill"
        case .gigaChad, .gigaStacy:          return "diamond.fill"
        }
    }
}
