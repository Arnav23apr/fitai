import SwiftUI

/// Onboarding typography tokens. Color/material tokens used to live
/// here too, but the milestone screens (TrustUs, PhysiqueReward,
/// Commitment) now read their visual language from the shared Metal
/// FX pieces (`PremiumBackdrop`, `HalationGlow`, `MercuryRingButton`,
/// `GodRaySweep`) — so the only thing this file owns is the headline
/// scale that those screens use consistently.
enum OnboardingTheme {

    /// Onboarding headline font. Bold sans-serif — `.serif` is
    /// intentionally excluded because mixing serif headlines with
    /// the dominantly sans-serif data-entry flow was the original
    /// inconsistency the designer flagged.
    static func headline(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Slightly smaller variant for secondary milestone headlines
    /// (Trust, Commitment, etc.). Same weight, system `.largeTitle`
    /// scale so the hierarchy reads even on smaller devices.
    static func headlineCompact() -> Font {
        .system(.largeTitle, weight: .bold)
    }
}
