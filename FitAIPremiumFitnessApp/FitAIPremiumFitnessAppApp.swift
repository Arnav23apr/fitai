import SwiftUI
import Auth

@main
struct FitAIPremiumFitnessAppApp: App {
    @State private var appState = AppState()
    @State private var tourManager = TourManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(tourManager)
                .preferredColorScheme(appState.profile.forceDarkMode ? .dark : nil)
                .onOpenURL { url in
                    supabaseAuth.handle(url)
                }
        }
    }
}
