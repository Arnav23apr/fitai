import Foundation
import Testing
@testable import FitAI

struct LocalizationIntegrityTests {

    @Test("English localization contains critical app keys")
    func englishContainsCriticalKeys() throws {
        let english = try #require(L.translations["English"])
        let keys = criticalKeys()

        #expect(keys.allSatisfy { key in
            guard let value = english[key] else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
    }

    @Test("Every language has critical navigation, paywall, and settings keys")
    func everyLanguageHasCriticalKeys() {
        let keys = criticalKeys()
        let missing = L.translations.flatMap { language, table in
            keys.compactMap { key in
                table[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? nil
                    : "\(language).\(key)"
            }
        }

        #expect(missing.isEmpty, "Missing critical localization keys: \(missing.sorted().joined(separator: ", "))")
    }

    @Test("Localization falls back to English and then the key")
    func localizationFallbacks() {
        #expect(L.t("scan", "Not A Language") == L.translations["English"]?["scan"])
        #expect(L.t("missing_test_key", "English") == "missing_test_key")
    }

    @Test("Apple Health key exists for every language")
    func appleHealthExistsEverywhere() {
        let missing = L.translations.keys
            .filter { L.t("appleHealth", $0) == "appleHealth" }
            .sorted()

        #expect(missing.isEmpty, "Missing appleHealth key in: \(missing.joined(separator: ", "))")
    }

    private func criticalKeys() -> [String] {
        [
            "getStarted",
            "continue",
            "cancel",
            "logIn",
            "logOut",
            "scan",
            "plan",
            "compete",
            "profile",
            "appleHealth",
            "weight",
            "workouts",
            "scans",
            "scanHistory",
            "currentPlan",
            "manageSubscription",
            "restorePurchases",
            "monthly",
            "yearly",
            "lifetime",
        ]
    }
}
