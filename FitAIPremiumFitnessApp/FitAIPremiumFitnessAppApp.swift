import SwiftUI

@main
struct FitAIPremiumFitnessAppApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
