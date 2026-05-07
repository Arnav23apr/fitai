import SwiftUI
import PhotosUI
import RevenueCatUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(TourManager.self) private var tourManager
    @State private var showEditProfile: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showLanguagePicker: Bool = false
    @State private var showAppleHealth: Bool = false
    @State private var showNotificationSettings: Bool = false
    @State private var showCurrentPlan: Bool = false
    @State private var showWeightHeightEditor: Bool = false
    @State private var showCustomerCenter: Bool = false
    @State private var showWorkoutPreferences: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var showFeedback: Bool = false
    @State private var feedbackInitialKind: FeedbackService.Kind = .bug
    @State private var showPreCancelIntercept: Bool = false
    @State private var showMeasurements: Bool = false
    @State private var showPhotosAndData: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        userCard
                            .tourAnchor(.profileUserCard)
                        weightHeightCard
                        statsCard
                        if appState.profile.spinDiscount != nil && !appState.profile.isPremium {
                            limitedOfferCard
                        }
                        if appState.profile.canSeeGoalProjection {
                            GoalProjectionCard(context: .profile)
                        }
                        WorkoutCalendarHeatmap(logs: appState.profile.workoutLogs)
                        scanHistorySection
                        settingsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .tourAutoScroll(tab: 3, proxy: scrollProxy)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("profile", lang))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.profile.isPremium {
                        Button { showCurrentPlan = true } label: {
                            Text("PRO")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
            .sheet(isPresented: $showPaywall) { PaywallSheet() }
            .sheet(isPresented: $showCurrentPlan) {
                CurrentPlanSheet()
                    .presentationDetents([.fraction(0.75)])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
                    .presentationDetents([.fraction(0.85), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
            }
            .sheet(isPresented: $showPhotosAndData) {
                PhotosAndDataSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLanguagePicker) { LanguagePickerSheet() }
            .sheet(isPresented: $showWeightHeightEditor) {
                WeightHeightEditorSheet()
                    .presentationDetents([.fraction(0.65), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAppleHealth) {
                AppleHealthView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackSheet(initialKind: feedbackInitialKind)
            }
            .sheet(isPresented: $showMeasurements) {
                BodyMeasurementsSheet()
            }
            .sheet(isPresented: $showPreCancelIntercept) {
                GoalProjectionCard(
                    context: .preCancel,
                    onProceedCancel: {
                        showPreCancelIntercept = false
                        // Hand off to the system manage-subscription sheet.
                        // Slight delay so the dismiss animation finishes
                        // before the next sheet presents (avoids a flicker).
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showCustomerCenter = true
                        }
                    },
                    onStaySubscribed: {
                        showPreCancelIntercept = false
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showWorkoutPreferences) {
                EditWorkoutPreferencesSheet()
                    .presentationDetents([.fraction(0.85), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
            }
        }
    }

    private var userCard: some View {
        HStack(spacing: 16) {
            Group {
                if let photoData = appState.profile.customPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } else {
                    Image(systemName: appState.profile.avatarSystemName)
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(appState.profile.name.isEmpty ? "Athlete" : appState.profile.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    if appState.profile.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            )
                    }
                }
                if !appState.profile.username.isEmpty {
                    Text("@\(appState.profile.username)")
                        .font(.caption)
                        .foregroundStyle(.blue.opacity(0.7))
                }
                if !appState.profile.goals.isEmpty {
                    Text(appState.profile.goals.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if !appState.profile.bio.isEmpty {
                    Text(appState.profile.bio)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(action: { showEditProfile = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(colors: [.blue.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var weightHeightCard: some View {
        let profile = appState.profile
        let isMetric = profile.usesMetric
        let heightCm = profile.heightCm
        let weightKg = profile.weightKg

        let heightText: String = {
            if isMetric { return "\(Int(heightCm)) cm" }
            let feet = Int(heightCm / 30.48)
            let inches = Int((heightCm / 2.54).truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        }()

        let weightText: String = {
            if isMetric { return "\(Int(weightKg)) kg" }
            return "\(Int(weightKg * 2.205)) lbs"
        }()

        return Button { showWeightHeightEditor = true } label: {
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "ruler")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Height")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(heightText)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 32)

                HStack(spacing: 10) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weight")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(weightText)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [.green.opacity(0.04), .cyan.opacity(0.03), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(colors: [.green.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            profileStat(value: "\(appState.profile.totalScans)", label: L.t("scans", lang))
            profileDivider
            profileStat(value: "\(appState.profile.totalWorkouts)", label: L.t("workouts", lang))
            profileDivider
            profileStat(value: "\(appState.profile.currentStreak)", label: L.t("streak", lang))
        }
        .padding(20)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.purple.opacity(0.04), .pink.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(colors: [.purple.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var profileDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 36)
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var limitedOfferCard: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("limitedOffer", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let discount = appState.profile.spinDiscount {
                        Text("\(discount)% off Pro - Claim now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(LinearGradient(colors: [Color.yellow.opacity(0.08), Color.orange.opacity(0.04)], startPoint: .leading, endPoint: .trailing))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1))
        }
    }

    private var scanHistorySection: some View {
        ScanHistoryGraphView(entries: appState.scanHistory)
    }

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.t("settings", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            if !appState.profile.isPremium {
                getProBanner
            }

            VStack(spacing: 0) {
                settingsRow(title: L.t("workoutPreferences", lang), icon: "dumbbell.fill", iconColor: .orange) {
                    showWorkoutPreferences = true
                }
                Divider().padding(.leading, 52)
                settingsRow(title: "Measurements", icon: "ruler.fill", iconColor: .indigo) {
                    showMeasurements = true
                }
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("notifications", lang), icon: "bell.fill", iconColor: .secondary) {
                    showNotificationSettings = true
                }
                Divider().padding(.leading, 52)
                weightUnitRow
                Divider().padding(.leading, 52)
                appleHealthRow
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("restorePurchases", lang), icon: "arrow.clockwise") {
                    Task {
                        await StoreViewModel.shared.restore()
                        if StoreViewModel.shared.isPremium {
                            appState.profile.isPremium = true
                            appState.saveProfile()
                        }
                    }
                }
                if appState.profile.isPremium {
                    Divider().padding(.leading, 52)
                    settingsRow(title: "Manage Subscription", icon: "crown.fill", iconColor: .yellow) {
                        // If we have a goal projection, intercept with the
                        // "this is who you walk away from" sheet first. Users
                        // can still proceed to the system manage sheet from
                        // there. No projection → straight to the system sheet.
                        if appState.profile.goalProjectionURL != nil {
                            showPreCancelIntercept = true
                        } else {
                            showCustomerCenter = true
                        }
                    }
                }
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("language", lang), icon: "globe", trailing: appState.profile.selectedLanguage) {
                    showLanguagePicker = true
                }
                Divider().padding(.leading, 52)
                // Single feedback entry — the kind picker (bug/suggestion)
                // lives inside FeedbackSheet, so we don't need two rows
                // that both open the same sheet.
                settingsRow(title: L.t("sendFeedback", lang), icon: "paperplane.fill", iconColor: Color(red: 0.20, green: 0.55, blue: 1.00)) {
                    feedbackInitialKind = .suggestion
                    showFeedback = true
                }
                Divider().padding(.leading, 52)
                settingsRow(title: "Photos & Data", icon: "lock.shield.fill", iconColor: .green) {
                    showPhotosAndData = true
                }
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("termsPrivacy", lang), icon: "doc.text") {
                    UIApplication.shared.open(LegalLinks.terms)
                }
                Divider().padding(.leading, 52)
                workoutModeResetRow
                Divider().padding(.leading, 52)
                exerciseDataAttributionRow
                Divider().padding(.leading, 52)
                restartTourRow
            }
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [.cyan.opacity(0.03), .blue.opacity(0.02), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 16))
            .tourAnchor(.profileSettings)

            Button(action: { appState.logout() }) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text(L.t("logOut", lang))
                        .font(.subheadline)
                }
                .foregroundStyle(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
            }

            Button(action: { showDeleteConfirm = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("Delete Account")
                        .font(.subheadline)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete My Account", role: .destructive) {
                    isDeletingAccount = true
                    Task {
                        await appState.deleteAccount()
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .overlay {
                if isDeletingAccount {
                    ProgressView()
                }
            }
        }
    }

    private var getProBanner: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock FitAI Pro 🏆")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Reach your dream physique faster.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Try Free")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(.capsule)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.08), Color.orange.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    /// Lets the user re-pick their Workouts-tab mode (AI plan / custom /
    /// reviewed). Sets `workoutMode = .unset` so the choice screen
    /// re-presents on next visit.
    private var workoutModeResetRow: some View {
        Button {
            appState.profile.workoutMode = .unset
            appState.saveProfile()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.cyan)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout mode")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(appState.profile.workoutMode.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Change")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    /// Attribution for the open-source exercise databases bundled with FitAI.
    /// Required by their licenses (MIT for free-exercise-db, CC-BY-SA 4.0 for
    /// wger.de). Tap opens wger.de's site so users can verify the upstream.
    private var exerciseDataAttributionRow: some View {
        Button {
            if let url = URL(string: "https://wger.de/") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercise Database Credits")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("free-exercise-db (MIT) · wger.de (CC-BY-SA 4.0)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var restartTourRow: some View {
        Button { tourManager.restartTour() } label: {
            HStack(spacing: 14) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                Text("Restart Tour")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .tourAnchor(.profileRestartTour)
    }

    private var weightUnitRow: some View {
        Button {
            appState.profile.usesMetric.toggle()
            appState.saveProfile()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(L.t("weightUnit", lang))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(appState.profile.usesMetric ? "kg" : "lbs")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var appleHealthRow: some View {
        Button(action: { showAppleHealth = true }) {
            HStack(spacing: 14) {
                AppleHealthIconMark()
                    .frame(width: 24, height: 24)
                Text(L.t("appleHealth", lang))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func settingsRow(title: String, icon: String, iconColor: Color = .secondary, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var customPhotoData: Data? = nil

    private let avatarOptions = [
        "person.crop.circle.fill", "figure.run", "figure.strengthtraining.traditional",
        "figure.boxing", "figure.martial.arts", "dumbbell.fill"
    ]
    @State private var selectedAvatar: String = "person.crop.circle.fill"
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameCheckTask: Task<Void, Never>? = nil

    enum UsernameStatus: Equatable {
        case idle
        case invalid(UsernameValidationError)
        case checking
        case available
        case taken
        case error
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            if let photoData = customPhotoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: selectedAvatar)
                                    .font(.system(size: 56))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 88, height: 88)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(Circle())
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(.systemBackground))
                                    .frame(width: 28, height: 28)
                                    .background(Color(.label))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                            }
                            .offset(x: 2, y: 2)
                        }

                        if customPhotoData != nil {
                            Button(L.t("removePhoto", appState.profile.selectedLanguage)) {
                                withAnimation { customPhotoData = nil; selectedPhotoItem = nil }
                            }
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(avatarOptions, id: \.self) { avatar in
                                    Button(action: { selectedAvatar = avatar; customPhotoData = nil; selectedPhotoItem = nil }) {
                                        Image(systemName: avatar)
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedAvatar == avatar && customPhotoData == nil ? Color(.systemBackground) : .secondary)
                                            .frame(width: 44, height: 44)
                                            .background(selectedAvatar == avatar && customPhotoData == nil ? Color(.label) : Color(.secondarySystemGroupedBackground))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .contentMargins(.horizontal, 0)
                    }

                    VStack(spacing: 14) {
                        TextField(L.t("name", appState.profile.selectedLanguage), text: $name)
                            .font(.body).foregroundStyle(.primary)
                            .padding(16).background(Color(.secondarySystemGroupedBackground))
                            .clipShape(.rect(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 0) {
                                Text("@").font(.body.weight(.medium)).foregroundStyle(.secondary).padding(.leading, 16)
                                TextField("username", text: $username)
                                    .font(.body).foregroundStyle(.primary)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .padding(.vertical, 16).padding(.leading, 4).padding(.trailing, 16)
                                    .onChange(of: username) { _, newValue in
                                        scheduleUsernameCheck(newValue)
                                    }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(usernameBorderColor, lineWidth: usernameBorderColor == .clear ? 0 : 1)
                            )
                            .animation(.snappy(duration: 0.2), value: usernameStatus)

                            usernameStatusLabel
                                .padding(.leading, 4)
                                .animation(.snappy(duration: 0.2), value: usernameStatus)
                        }

                        TextField(L.t("shortBio", appState.profile.selectedLanguage), text: $bio)
                            .font(.body).foregroundStyle(.primary)
                            .padding(16).background(Color(.secondarySystemGroupedBackground))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("editProfile", appState.profile.selectedLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", appState.profile.selectedLanguage)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save", appState.profile.selectedLanguage)) {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(usernameStatus == .checking)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        customPhotoData = data
                    }
                }
            }
        }
        .onAppear {
            name = appState.profile.name
            username = appState.profile.username
            bio = appState.profile.bio
            selectedAvatar = appState.profile.avatarSystemName
            customPhotoData = appState.profile.customPhotoData
        }
    }

    private var usernameBorderColor: Color {
        switch usernameStatus {
        case .available: return .green.opacity(0.6)
        case .taken, .invalid: return .red.opacity(0.6)
        default: return .clear
        }
    }

    @ViewBuilder
    private var usernameStatusLabel: some View {
        switch usernameStatus {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("Checking…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .available:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("Username available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }
        case .taken:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text("Username not available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
        case .invalid(let err):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text(UsernameValidator.message(for: err))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
        case .error:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("Couldn't verify. Check connection.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func scheduleUsernameCheck(_ raw: String) {
        usernameCheckTask?.cancel()

        let normalized = raw.lowercased().trimmingCharacters(in: .whitespaces)
        let current = appState.profile.username.lowercased()

        if normalized.isEmpty || normalized == current {
            usernameStatus = .idle
            return
        }

        if let err = UsernameValidator.validate(normalized) {
            usernameStatus = .invalid(err)
            return
        }

        usernameStatus = .checking

        usernameCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }

            let result = await appState.isUsernameAvailable(normalized)
            if Task.isCancelled { return }

            switch result {
            case .some(true):  usernameStatus = .available
            case .some(false): usernameStatus = .taken
            case .none:        usernameStatus = .error
            }
        }
    }

    @MainActor
    private func save() async {
        let normalized = username.lowercased().trimmingCharacters(in: .whitespaces)
        let current = appState.profile.username.lowercased()
        let usernameDidChange = !normalized.isEmpty && normalized != current

        if usernameDidChange {
            switch usernameStatus {
            case .available:
                break
            case .taken, .invalid, .error:
                return
            case .checking, .idle:
                if let validationError = UsernameValidator.validate(normalized) {
                    usernameStatus = .invalid(validationError)
                    return
                }
                usernameStatus = .checking
                let available = await appState.isUsernameAvailable(normalized)
                switch available {
                case .some(false):
                    usernameStatus = .taken
                    return
                case .none:
                    usernameStatus = .error
                    return
                case .some(true):
                    usernameStatus = .available
                }
            }
        }

        appState.profile.name = name
        appState.profile.username = normalized
        appState.profile.bio = bio
        appState.profile.avatarSystemName = selectedAvatar
        if usernameDidChange {
            appState.profile.usernameChangedAt = Date()
        }
        // Photo update goes through `setCustomPhotoData` so the avatar
        // also uploads to Supabase Storage (cross-device sync). It calls
        // saveProfile() internally, so we don't double-save.
        appState.setCustomPhotoData(customPhotoData)

        // Identity fields are skipped by the bulk upsert; sync them
        // explicitly here since the user just changed them on purpose.
        if let userId = appState.currentUserIdPublic {
            let nameToSync = name
            let usernameToSync = normalized
            Task.detached {
                await SupabaseSyncService.shared.setIdentity(
                    userId: userId,
                    name: nameToSync,
                    username: usernameToSync,
                    email: nil
                )
            }
        }
        dismiss()
    }
}

struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedLanguage: String = "English"

    private let languages: [(name: String, flag: String, native: String)] = [
        ("English", "🇺🇸", "English"), ("Arabic", "🇸🇦", "العربية"), ("Chinese", "🇨🇳", "中文"),
        ("Dutch", "🇳🇱", "Nederlands"), ("French", "🇫🇷", "Français"), ("German", "🇩🇪", "Deutsch"),
        ("Hebrew", "🇮🇱", "עברית"), ("Hindi", "🇮🇳", "हिन्दी"), ("Italian", "🇮🇹", "Italiano"),
        ("Japanese", "🇯🇵", "日本語"), ("Korean", "🇰🇷", "한국어"), ("Polish", "🇵🇱", "Polski"),
        ("Portuguese", "🇧🇷", "Português"), ("Romanian", "🇷🇴", "Română"), ("Russian", "🇷🇺", "Русский"),
        ("Spanish", "🇪🇸", "Español"), ("Swedish", "🇸🇪", "Svenska"), ("Turkish", "🇹🇷", "Türkçe"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(languages, id: \.name) { language in
                    Button {
                        selectedLanguage = language.name
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag).font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.native).font(.body.weight(.medium)).foregroundStyle(.primary)
                                if language.native != language.name {
                                    Text(language.name).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedLanguage == language.name {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.green)
                            }
                        }
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("language", appState.profile.selectedLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", appState.profile.selectedLanguage)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save", appState.profile.selectedLanguage)) {
                        appState.profile.selectedLanguage = selectedLanguage
                        appState.saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { selectedLanguage = appState.profile.selectedLanguage }
    }
}

struct AppleHealthIconMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let isDark = colorScheme == .dark

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                            .strokeBorder(
                                isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )

                Image("AppleHealthLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.84, height: size * 0.84)
            }
            .frame(width: size, height: size)
        }
    }
}
