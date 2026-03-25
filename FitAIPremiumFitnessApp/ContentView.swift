import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            // Background color matches the active screen to eliminate color flash on transition:
            // SwipeUpSplash → white, WelcomeView → near-black, MainTabView → systemBackground
            if appState.showSplash {
                Color.white.ignoresSafeArea()
            } else if !appState.hasCompletedOnboarding {
                Color(red: 0.028, green: 0.028, blue: 0.034).ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            if appState.showSplash {
                SwipeUpSplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        appState.showSplash = false
                    }
                }
                .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingContainerView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}
