import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: Int = 0
    @State private var appeared: Bool = false
    @State private var showTour: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab(L.t("scan", lang), systemImage: "camera.viewfinder", value: 0) {
                    ScanView()
                }
                Tab(L.t("plan", lang), systemImage: "calendar.badge.clock", value: 1) {
                    PlanView()
                }
                Tab(L.t("compete", lang), systemImage: "trophy.fill", value: 2) {
                    CompeteView()
                }
                Tab(L.t("profile", lang), systemImage: "person.fill", value: 3) {
                    ProfileView()
                }
            }
            .tint(.primary)

            if showTour {
                GuidedTourOverlay(isShowing: $showTour, selectedTab: $selectedTab)
                    .transition(.opacity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }

            if appState.showGuidedTour && !UserDefaults.standard.bool(forKey: "hasSeenGuidedTour") {
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showTour = true
                    }
                    appState.showGuidedTour = false
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: showTour)
    }
}
