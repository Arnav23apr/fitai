// Template for `Secrets.swift`. Copy this file to `Secrets.swift` (next to
// it) and fill in your real keys. `Secrets.swift` is gitignored so secrets
// never leave your machine.
//
// On a fresh clone:
//   1. cp ios/FitAIPremiumFitnessApp/Secrets.example.swift \
//        ios/FitAIPremiumFitnessApp/Secrets.swift
//   2. Open Secrets.swift, paste your keys.
//   3. Build.

#if false
import Foundation

enum Secrets {
    /// Gemini API key from https://aistudio.google.com/apikey
    static let geminiAPIKey: String = "AIza_PASTE_YOUR_GEMINI_KEY_HERE"

    /// RevenueCat sandbox / test key (used in DEBUG builds)
    /// From RevenueCat dashboard: Project settings -> API keys
    static let revenueCatTestAPIKey: String = "appl_or_test_PASTE_HERE"

    /// RevenueCat production key (used in RELEASE builds)
    /// Without this, App Store builds will not initialize Purchases and
    /// Pro will not work.
    static let revenueCatProductionAPIKey: String = "appl_PASTE_HERE"
}
#endif
