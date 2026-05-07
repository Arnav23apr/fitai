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
        #if DEBUG
        let rcKey = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        let label = "DEBUG (sandbox)"
        #else
        let rcKey = Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY
        let label = "RELEASE (production)"
        #endif
        if rcKey.isEmpty {
            // Loud runtime warning so a missing key doesn't silently kill
            // every Pro flow. Search the console for [RC] to find it.
            print("[RC] WARNING: No \(label) RevenueCat API key set. Paywalls and entitlement checks will all fail. Paste a key into Secrets.swift.")
        } else {
            Purchases.configure(withAPIKey: rcKey)
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
                    await StoreViewModel.shared.fetchOfferings()
                    // Wait for RevenueCat to actually return customer info
                    // before reconciling. fetchOfferings() only loads
                    // packages, not entitlements — without this awaited
                    // refresh, syncPremiumStatus() reads StoreViewModel's
                    // default `isPremium = false` and downgrades the
                    // profile every cold launch (the bug where Pro
                    // disappears on every relaunch).
                    await StoreViewModel.shared.refreshPremiumStatus()
                    syncPremiumStatus()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await StoreViewModel.shared.fetchOfferings()
                        await StoreViewModel.shared.refreshPremiumStatus()
                        syncPremiumStatus()
                        // Bump presence heartbeat — friends will see us as
                        // online for the next 5 min after every foreground.
                        await appState.bumpPresence()
                    }
                }
        }
    }

    /// Reconciles `profile.isPremium` against RevenueCat's view of the
    /// world. Caller MUST await `refreshPremiumStatus()` first so we're
    /// reading a fresh entitlement, not StoreViewModel's default-false.
    private func syncPremiumStatus() {
        let rcPremium = StoreViewModel.shared.isPremium
        if rcPremium && !appState.profile.isPremium {
            appState.profile.isPremium = true
            appState.saveProfile()
        } else if !rcPremium && appState.profile.isPremium && Purchases.isConfigured {
            // RevenueCat is loaded and confirms not premium — revoke cached flag
            appState.profile.isPremium = false
            appState.saveProfile()
        }
    }
}
