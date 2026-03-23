import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
class StoreViewModel {
    static let shared = StoreViewModel()

    var offerings: Offerings?
    var isPremium: Bool = false
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?

    private init() {
        guard Purchases.isConfigured else { return }
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
    }

    private func listenForUpdates() async {
        guard Purchases.isConfigured else { return }
        for await info in Purchases.shared.customerInfoStream {
            isPremium = info.entitlements["Fit AI Pro"]?.isActive == true
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
        } catch ErrorCode.paymentPendingError {
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

    /// Refresh premium status from RevenueCat. Call after any entitlement-gating check.
    func refreshPremiumStatus() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements["Fit AI Pro"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
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

    var monthlyPriceString: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "$9.99"
    }

    var annualPriceString: String {
        annualPackage?.storeProduct.localizedPriceString ?? "$119.99"
    }

    var lifetimePriceString: String {
        lifetimePackage?.storeProduct.localizedPriceString ?? "$149.99"
    }
}
