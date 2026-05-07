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
            } else if (appState.showSplash || appState.bootstrapping) && !appState.hasCompletedOnboarding {
                // SwipeUpSplashView is the welcome / drag-up gate for users
                // who haven't onboarded yet. Returning users (already
                // hasCompletedOnboarding) should never see it, even for the
                // single frame between logo splash dismissing and Main
                // appearing — that flash was the visible bug.
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
                    .fullScreenCover(isPresented: Binding(
                        get: {
                            // Backfill: existing accounts that completed
                            // onboarding before usernames were required
                            // get a one-time forced picker on launch.
                            appState.isLoggedIn
                            && appState.profile.username
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        },
                        set: { _ in }
                    )) {
                        UsernamePickerView(
                            title: "Pick your handle",
                            subtitle: "Friends need a way to find you. Lock in your @ now — you can change it later.",
                            isModal: true,
                            onConfirm: { final in
                                appState.profile.username = final
                                await SupabaseSyncService.shared.setIdentity(
                                    userId: appState.currentUserIdPublic ?? "",
                                    name: appState.profile.name,
                                    username: final,
                                    email: appState.profile.email
                                )
                            }
                        )
                        .interactiveDismissDisabled()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.showLogoSplash)
        .animation(.easeInOut(duration: 0.5), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.5), value: appState.bootstrapping)
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}
