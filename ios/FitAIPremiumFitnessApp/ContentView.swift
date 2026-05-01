import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var startAtLogin: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if appState.showLogoSplash {
                SplashView(onFinished: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appState.showLogoSplash = false
                    }
                })
                .transition(.opacity)
            } else if appState.showSplash || appState.bootstrapping {
                SwipeUpSplashView(
                    onFinished: {
                        startAtLogin = false
                        withAnimation(.easeInOut(duration: 0.5)) {
                            appState.showSplash = false
                        }
                    },
                    onLogin: {
                        startAtLogin = true
                        withAnimation(.easeInOut(duration: 0.5)) {
                            appState.showSplash = false
                        }
                    }
                )
                .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingContainerView(startAtLogin: startAtLogin)
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.showLogoSplash)
        .animation(.easeInOut(duration: 0.5), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.5), value: appState.bootstrapping)
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}
