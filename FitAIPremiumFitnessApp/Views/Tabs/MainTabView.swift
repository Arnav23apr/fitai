import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var appeared: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Scan", systemImage: "camera.viewfinder", value: 0) {
                ScanView()
            }
            Tab("Plan", systemImage: "calendar.badge.clock", value: 1) {
                PlanView()
            }
            Tab("Compete", systemImage: "trophy.fill", value: 2) {
                CompeteView()
            }
            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView()
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(white: 0.06, alpha: 1)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}
