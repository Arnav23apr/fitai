import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.4), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}
