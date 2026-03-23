import SwiftUI
import Auth
import UserNotifications
import RevenueCat

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
}

@main
struct FitAIPremiumFitnessAppApp: App {
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
                .preferredColorScheme(appState.profile.forceDarkMode ? .dark : nil)
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
                    await StoreViewModel.shared.fetchOfferings()
                    if StoreViewModel.shared.isPremium && !appState.profile.isPremium {
                        appState.profile.isPremium = true
                        appState.saveProfile()
                    }
                }
        }
    }
}
