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
        .onGeometryChange(for: CGRect.self, of: { geo in geo.frame(in: .global) }) { _ in
            registerTabBarFrame()
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

            registerTabBarFrame()
            tourManager.checkAndShowWelcome()
        }
    }

    private func registerTabBarFrame() {
        let screen = UIScreen.main.bounds
        let safeBottom: CGFloat
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            safeBottom = window.safeAreaInsets.bottom
        } else {
            safeBottom = 34
        }
        let tabBarPillHeight: CGFloat = 50
        let bottomPadding: CGFloat = safeBottom > 0 ? 2 : 4
        let pillBottomY = screen.height - safeBottom + bottomPadding
        let pillTopY = pillBottomY - tabBarPillHeight
        let insetH: CGFloat = 16
        let frame = CGRect(
            x: insetH,
            y: pillTopY,
            width: screen.width - insetH * 2,
            height: tabBarPillHeight
        )
        tourManager.registerAnchor(.tabBar, frame: frame)
    }
}
