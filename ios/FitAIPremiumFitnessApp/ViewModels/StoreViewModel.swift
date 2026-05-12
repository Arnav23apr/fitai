import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
class StoreViewModel {
    static let shared = StoreViewModel()

    var offerings: Offerings?
    var isPremium: Bool = false
    /// Set to `true` the first time RevenueCat returns a definitive answer
    /// (either via `customerInfoStream` or an awaited `refreshPremiumStatus`).
    /// Callers that *downgrade* `profile.isPremium` should only act when
    /// this is true — otherwise a network blip or pre-init race silently
    /// flips legitimate Pro users back to free.
    var hasConfirmedPremiumState: Bool = false
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?

    /// Fired on every RC `customerInfoStream` emission, immediately after
    /// `isPremium` is updated. The app root wires this to mirror the
    /// state onto `appState.profile.isPremium` so feature gates inside
    /// sheets never lag behind RC's truth.
    var onPremiumStateChange: ((Bool) -> Void)? = nil

    private init() {
        guard Purchases.isConfigured else { return }
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
    }

    private func listenForUpdates() async {
        guard Purchases.isConfigured else { return }
        for await info in Purchases.shared.customerInfoStream {
            let active = info.entitlements["Fit AI Pro"]?.isActive == true
            isPremium = active
            hasConfirmedPremiumState = true
            onPremiumStateChange?(active)
        }
    }

    func fetchOfferings() async {
        guard Purchases.isConfigured else { return }
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func purchase(package: Package) async -> Bool {
        guard Purchases.isConfigured else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                isPremium = result.customerInfo.entitlements["Fit AI Pro"]?.isActive == true
                return isPremium
            }
        } catch ErrorCode.purchaseCancelledError {
            // User intentionally cancelled — no error needed
        } catch ErrorCode.paymentPendingError {
            self.error = "Your purchase is pending approval. You'll get access once it's confirmed."
        } catch {
            self.error = error.localizedDescription
        }
        return false
    }

    func restore() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements["Fit AI Pro"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh premium status from RevenueCat. Call after any entitlement-
    /// gating check. Returns the freshly-fetched state, or `nil` when RC
    /// couldn't be reached — callers must NOT downgrade on `nil` because
    /// "unknown" is not the same as "not premium".
    @discardableResult
    func refreshPremiumStatus() async -> Bool? {
        guard Purchases.isConfigured else { return nil }
        do {
            let info = try await Purchases.shared.customerInfo()
            let active = info.entitlements["Fit AI Pro"]?.isActive == true
            isPremium = active
            hasConfirmedPremiumState = true
            onPremiumStateChange?(active)
            return active
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    var weeklyPackage: Package? {
        offerings?.current?.package(identifier: "weekly")
            ?? offerings?.current?.package(identifier: "$rc_weekly")
    }

    var monthlyPackage: Package? {
        offerings?.current?.package(identifier: "monthly")
            ?? offerings?.current?.package(identifier: "$rc_monthly")
    }

    var annualPackage: Package? {
        offerings?.current?.package(identifier: "yearly")
            ?? offerings?.current?.package(identifier: "$rc_annual")
    }

    var lifetimePackage: Package? {
        offerings?.current?.package(identifier: "lifetime")
            ?? offerings?.current?.package(identifier: "$rc_lifetime")
    }

    var weeklyPriceString: String {
        weeklyPackage?.storeProduct.localizedPriceString ?? "$4.99"
    }

    var monthlyPriceString: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "$9.99"
    }

    var annualPriceString: String {
        annualPackage?.storeProduct.localizedPriceString ?? "$49.99"
    }

    var lifetimePriceString: String {
        lifetimePackage?.storeProduct.localizedPriceString ?? "$99.99"
    }

    /// % saved on annual vs paying weekly for a year. Used for the "SAVE X%"
    /// badge on the yearly card. Rounds down to nearest 5%.
    var annualVsWeeklySavingsPercent: Int {
        guard
            let weekly = weeklyPackage?.storeProduct.price,
            let annual = annualPackage?.storeProduct.price
        else { return 80 }
        let weeklyAnnualized = NSDecimalNumber(decimal: weekly).doubleValue * 52.0
        let annualValue = NSDecimalNumber(decimal: annual).doubleValue
        guard weeklyAnnualized > 0 else { return 80 }
        let pct = (1.0 - annualValue / weeklyAnnualized) * 100.0
        return max(0, min(95, Int((pct / 5.0).rounded(.down) * 5.0)))
    }

    /// Per-week framing: yearly price / 52. Reframes a $119.99 lump sum as
    /// "$2.31/week" — the move every successful AI app paywall in the corpus
    /// converged on (Cal AI, Halo AI, Pingo, Cleo, Glow Up, etc.).
    var annualPriceWeeklyString: String {
        guard let product = annualPackage?.storeProduct else { return "$2.31" }
        let weekly = NSDecimalNumber(decimal: product.price).doubleValue / 52.0
        return Self.formatCurrency(weekly, formatter: product.priceFormatter)
    }

    var monthlyPriceWeeklyString: String {
        guard let product = monthlyPackage?.storeProduct else { return "$2.31" }
        let weekly = NSDecimalNumber(decimal: product.price).doubleValue * 12.0 / 52.0
        return Self.formatCurrency(weekly, formatter: product.priceFormatter)
    }

    private static func formatCurrency(_ amount: Double, formatter: NumberFormatter?) -> String {
        if let f = formatter, let s = f.string(from: NSNumber(value: amount)) { return s }
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
}
