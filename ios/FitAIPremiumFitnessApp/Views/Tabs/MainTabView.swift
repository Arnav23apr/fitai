import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(TourManager.self) private var tourManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false
    @State private var showResumeWorkout: Bool = false
    /// Share overlay presented after a finished resume-flow workout. Owned
    /// here (not inside ActiveSessionView) so the cover unwinds first,
    /// preventing the fresh-session re-launch bug.
    @State private var pendingShareData: WorkoutShareCardData? = nil

    private let session = WorkoutSessionManager.shared
    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        @Bindable var tour = tourManager
        TabView(selection: $tour.selectedTab) {
            Tab(L.t("scan", lang), systemImage: "camera.viewfinder", value: 0) {
                ScanView()
            }
            .accessibilityLabel("Scan tab")
            .accessibilityHint("Body scan and physique analysis")
            Tab("Workouts", systemImage: "dumbbell.fill", value: 1) {
                PlanView()
            }
            .accessibilityLabel("Workouts tab")
            .accessibilityHint("Start, log, and track your workouts")
            Tab(L.t("compete", lang), systemImage: "trophy.fill", value: 2) {
                CompeteView()
            }
            .accessibilityLabel("Compete tab")
            .accessibilityHint("Leaderboards, battles, and challenges")
            Tab(L.t("profile", lang), systemImage: "person.fill", value: 3) {
                ProfileView()
            }
            .accessibilityLabel("Profile tab")
            .accessibilityHint("Your profile and settings")
        }
        .tint(.primary)
        .opacity(appeared ? 1 : 0)
        .onGeometryChange(for: CGRect.self, of: { geo in geo.frame(in: .global) }) { _ in
            registerTabBarFrame()
        }
        .overlay(alignment: .bottom) {
            if session.isActive {
                WorkoutResumePill(session: session) {
                    showResumeWorkout = true
                }
                .padding(.bottom, 56)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.4, bounce: 0.2), value: session.isActive)
            }
        }
        .overlay {
            TourOverlayView()
                .allowsHitTesting(tourManager.showWelcome || (tourManager.isActive && tourManager.stepReady))
        }
        .overlay(alignment: .top) {
            InAppBannerOverlay()
        }
        .sheet(isPresented: $showResumeWorkout) {
            if session.isActive {
                ActiveSessionView(
                    initialName: session.workoutName,
                    initialIcon: session.workoutIcon.isEmpty ? "dumbbell.fill" : session.workoutIcon,
                    initialExercises: session.exercises.map(RoutineExercise.init(from:)),
                    defaultRestSeconds: 90,
                    sourceTemplateId: nil,
                    onFinish: { share in
                        showResumeWorkout = false
                        if let share {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                pendingShareData = share
                            }
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(item: $pendingShareData.asIdentifiable) { wrapper in
            WorkoutShareOverlay(
                data: wrapper.value,
                onDismiss: { pendingShareData = nil }
            )
            .background(ClearBackground())
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
            session.resumeIfNeeded()
        }
        .onChange(of: tourManager.isActive) { _, active in
            if active { registerTabBarFrame() }
        }
        .onChange(of: tourManager.showWelcome) { _, showing in
            if showing { registerTabBarFrame() }
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
        let pillBottomY = screen.height - safeBottom + 6
        let pillTopY = pillBottomY - tabBarPillHeight
        let insetH: CGFloat = 25
        let frame = CGRect(
            x: insetH,
            y: pillTopY,
            width: screen.width - insetH * 2,
            height: tabBarPillHeight
        )
        tourManager.registerAnchor(.tabBar, frame: frame)
    }
}
