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

    static let EXPO_PUBLIC_REVENUECAT_IOS_API_KEY: String =
        Bundle.main.object(forInfoDictionaryKey: "EXPO_PUBLIC_REVENUECAT_IOS_API_KEY") as? String ?? ""

    static let EXPO_PUBLIC_REVENUECAT_TEST_API_KEY: String =
        Bundle.main.object(forInfoDictionaryKey: "EXPO_PUBLIC_REVENUECAT_TEST_API_KEY") as? String
        ?? "test_WZhaefVVBzlJbMMNczIttHTaapu"

    static let GEMINI_API_KEY: String =
        Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
        ?? "REDACTED_LEAKED_KEY"
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
        #else
        let rcKey = Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY
        #endif
        if !rcKey.isEmpty {
            Purchases.configure(withAPIKey: rcKey)
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
                    syncPremiumStatus()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await StoreViewModel.shared.fetchOfferings()
                        syncPremiumStatus()
                        // Bump presence heartbeat — friends will see us as
                        // online for the next 5 min after every foreground.
                        await appState.bumpPresence()
                    }
                }
        }
    }

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
