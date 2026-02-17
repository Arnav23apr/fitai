import SwiftUI
import Auth

@main
struct FitAIPremiumFitnessAppApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    supabaseAuth.handle(url)
                }
        }
    }
}
