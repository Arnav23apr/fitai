import SwiftUI
import Auth
import UserNotifications
import RevenueCat
import UIKit

enum Config {
    static let SUPABASE_URL: String =
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        ?? "https://vwnlfwdsmhanicjgtfgj.supabase.co"

    static let SUPABASE_ANON_KEY: String =
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        ?? "sb_publishable_qub6PycwvOpzBgIKPfCxFA_vcic6noP"

    static let EXPO_PUBLIC_TOOLKIT_URL: String =
        Bundle.main.object(forInfoDictionaryKey: "EXPO_PUBLIC_TOOLKIT_URL") as? String ?? ""

    /// RevenueCat production iOS key. Loaded from `Secrets.swift` (gitignored).
    /// Required for RELEASE builds; without it, `Purchases.configure(...)`
    /// is never called and Pro entitlements always evaluate to false.
    static let EXPO_PUBLIC_REVENUECAT_IOS_API_KEY: String = Secrets.revenueCatProductionAPIKey

    /// RevenueCat sandbox / test key. Loaded from `Secrets.swift` (gitignored).
    /// Used in DEBUG builds for local sandbox testing with App Store
    /// sandbox accounts.
    static let EXPO_PUBLIC_REVENUECAT_TEST_API_KEY: String = Secrets.revenueCatTestAPIKey

    /// Gemini API key. Loaded from local `Secrets.swift` (gitignored).
    /// If `Secrets.swift` doesn't exist on a fresh clone, the build still
    /// succeeds but AI features will fail at runtime with a clear error
    /// (the empty fallback). Copy `Secrets.example.swift` to
    /// `Secrets.swift` and paste your key.
    static let GEMINI_API_KEY: String = Secrets.geminiAPIKey
}

@main
struct FitAIPremiumFitnessAppApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
    @State private var appState = AppState()
    @State private var tourManager = TourManager()
    @State private var notificationRouter = NotificationRouter()

    init() {
        // RC key resolution. CRITICAL: the RevenueCat SDK contains an
        // intentional assertion-failure crash if you initialize a Release
        // build with a `test_` prefixed key
        // (Configuration.APIKeyValidationResult.checkForSimulatedStoreAPIKeyInRelease).
        // It's a safety guard against shipping a misconfigured TestFlight
        // / App Store binary. So:
        //   - DEBUG: use the test key (sandbox app in your RC project).
        //   - RELEASE: use the production key (`appl_...`) ONLY. If absent,
        //     skip Purchases.configure entirely and log loudly. The app
        //     launches; Pro features are unavailable until a production key
        //     is supplied via Secrets.swift.
        let testKey = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        let prodKey = Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY
        #if DEBUG
        let rcKey = testKey
        let label = "DEBUG (sandbox)"
        #else
        let rcKey = prodKey
        let label = "RELEASE (production)"
        #endif
        if rcKey.isEmpty {
            print("[RC] WARNING: No \(label) RevenueCat API key set. Pro / paywall features disabled this run. Paste a key into Secrets.swift.")
        } else {
            Purchases.configure(withAPIKey: rcKey)
            print("[RC] Configured with key for: \(label)")
            #if DEBUG
            Purchases.logLevel = .info
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(tourManager)
                // Locked to dark globally — premium AAA aesthetic, no
                // light-mode UI in the app. Was previously gated on
                // `profile.forceDarkMode`; now always dark.
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    supabaseAuth.handle(url)
                }
                .task {
                    notificationRouter.tourManager = tourManager
                    UNUserNotificationCenter.current().delegate = notificationRouter
                    NotificationService.shared.reconcileAll(
                        profile: appState.profile,
                        scanHistory: appState.scanHistory
                    )
                    // Request APNs once per session — idempotent, kicks off
                    // the AppDelegate didRegister... callback which uploads
                    // the device token to push_tokens.
                    await PushNotificationService.shared.requestAuthorizationAndRegister()

                    // Wire RC's customer-info stream to the profile *once*
                    // so any entitlement update (purchase, refund, expiry,
                    // restore from another device) propagates live into
                    // `appState.profile.isPremium`. Without this, sheets
                    // presented while RC was still settling read stale
                    // `false` and disable Pro gates for legitimate Pro
                    // users (the "Coach button stays grey" bug).
                    StoreViewModel.shared.onPremiumStateChange = { [appState] active in
                        applyPremiumStateChange(active, appState: appState)
                    }

                    await StoreViewModel.shared.fetchOfferings()
                    // Wait for RevenueCat to actually return customer info
                    // before reconciling. fetchOfferings() only loads
                    // packages, not entitlements — without this awaited
                    // refresh, the sync reads StoreViewModel's default
                    // `false` and downgrades the profile every cold
                    // launch.
                    let rcAnswer = await StoreViewModel.shared.refreshPremiumStatus()
                    syncPremiumStatus(rcAnswer: rcAnswer)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await StoreViewModel.shared.fetchOfferings()
                        let rcAnswer = await StoreViewModel.shared.refreshPremiumStatus()
                        syncPremiumStatus(rcAnswer: rcAnswer)
                        // Bump presence heartbeat — friends will see us as
                        // online for the next 5 min after every foreground.
                        await appState.bumpPresence()
                    }
                }
        }
    }

    /// Reconciles `profile.isPremium` against RevenueCat's view of the
    /// world. Pass the result of `refreshPremiumStatus()`:
    ///   - `true`  → upgrade if not already premium
    ///   - `false` → downgrade if currently premium (RC explicitly said no)
    ///   - `nil`   → unknown (network failure, RC not configured); leave
    ///               the profile untouched. Never downgrade on uncertainty.
    private func syncPremiumStatus(rcAnswer: Bool?) {
        guard let rcPremium = rcAnswer else { return }
        if rcPremium && !appState.profile.isPremium {
            appState.profile.isPremium = true
            appState.saveProfile()
        } else if !rcPremium && appState.profile.isPremium {
            appState.profile.isPremium = false
            appState.saveProfile()
        }
    }
}

/// Applied on every `customerInfoStream` emission. Lives at file scope so
/// the closure handed to `StoreViewModel.onPremiumStateChange` doesn't
/// capture `self` (FitAIPremiumFitnessAppApp is a struct, but the closure
/// outlives any single render). Same semantics as `syncPremiumStatus`
/// minus the unknown-state guard: RC fired with concrete data, so we
/// trust the upgrade-or-downgrade signal directly.
@MainActor
private func applyPremiumStateChange(_ active: Bool, appState: AppState) {
    if active && !appState.profile.isPremium {
        appState.profile.isPremium = true
        appState.saveProfile()
    } else if !active && appState.profile.isPremium {
        appState.profile.isPremium = false
        appState.saveProfile()
    }
}
