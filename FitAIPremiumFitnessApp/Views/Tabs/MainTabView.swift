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
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                registerTabBarFrame()
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

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                registerTabBarFrame()
            }
            tourManager.checkAndShowWelcome()
        }
    }

    private func registerTabBarFrame() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else { return }

        if let tabBar = findTabBar(in: window) {
            let frame = tabBar.convert(tabBar.bounds, to: nil)
            let inset: CGFloat = 2
            let adjusted = CGRect(
                x: frame.origin.x + inset,
                y: frame.origin.y + inset,
                width: frame.width - inset * 2,
                height: frame.height - inset * 2
            )
            tourManager.registerAnchor(.tabBar, frame: adjusted)
        }
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        for subview in view.subviews {
            if let found = findTabBar(in: subview) {
                return found
            }
        }
        return nil
    }
}
