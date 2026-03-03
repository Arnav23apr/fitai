import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(TourManager.self) private var tourManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        @Bindable var tour = tourManager
        TabView(selection: $tour.selectedTab) {
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
        .opacity(appeared ? 1 : 0)
        .background {
            GeometryReader { geo in
                let totalHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                let tabBarHeight: CGFloat = 49 + geo.safeAreaInsets.bottom
                Color.clear
                    .frame(width: geo.size.width, height: tabBarHeight)
                    .position(x: geo.size.width / 2, y: totalHeight - tabBarHeight / 2 - geo.safeAreaInsets.top)
                    .tourAnchor(.tabBar)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            TourOverlayView()
                .allowsHitTesting(tourManager.showWelcome || (tourManager.isActive && tourManager.stepReady))
        }
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }

            tourManager.checkAndShowWelcome()
        }
    }
}
