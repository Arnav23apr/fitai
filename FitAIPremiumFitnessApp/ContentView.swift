import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if appState.showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appState.showSplash = false
                    }
                }
                .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingContainerView()
                    .transition(.opacity)
            } else if appState.showWelcomePro {
                WelcomeProView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appState.showWelcomePro = false
                        appState.showGuidedTour = true
                    }
                }
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.4), value: appState.showWelcomePro)
    }
}
