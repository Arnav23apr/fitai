import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var vm = NotificationSettingsViewModel()

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if !vm.systemPermissionGranted {
                        permissionBanner
                    }

                    if let pauseLabel = vm.pauseLabel {
                        pausedBanner(until: pauseLabel)
                    }

                    trainingSection
                    bodyCheckSection
                    activitySection
                    lifestyleSection
                    actionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onDisappear {
                vm.reconcile(profile: appState.profile, scanHistory: appState.scanHistory)
            }
            .sensoryFeedback(.success, trigger: vm.showTestSent)
        }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.slash.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications Disabled")
                    .font(.subheadline.weight(.semibold))
                Text("Enable in Settings to receive reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.orange)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Paused Banner

    private func pausedBanner(until date: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders Paused")
                    .font(.subheadline.weight(.semibold))
                Text("Until \(date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                vm.unpause()
            } label: {
                Text("Resume")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.indigo)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.indigo.opacity(0.08))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.indigo.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Training Section

    private var trainingSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Training", icon: "dumbbell.fill")

            VStack(spacing: 0) {
                settingsToggle(
                    title: "Workout Reminders",
                    icon: "flame.fill",
                    iconColor: .orange,
                    isOn: Binding(
                        get: { vm.settings.trainingRemindersEnabled },
                        set: { vm.settings.trainingRemindersEnabled = $0; vm.saveAndReconcile() }
                    )
                )

                if vm.settings.trainingRemindersEnabled {
                    Divider().padding(.leading, 52)

                    HStack(spacing: 14) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text("Reminder Time")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { vm.reminderTime },
                            set: { vm.reminderTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 52)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                                .frame(width: 28)
                            Text("Workout Days")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { weekday in
                                let isSelected = vm.settings.workoutDays.contains(weekday)
                                Button {
                                    vm.toggleDay(weekday)
                                } label: {
                                    Text(NotificationSettings.daySymbols[weekday - 1])
                                        .font(.system(.caption, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
                                        .background(isSelected ? Color(.label) : Color(.tertiarySystemGroupedBackground))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().padding(.leading, 52)

                settingsToggle(
                    title: "Missed Workout Nudge",
                    icon: "arrow.uturn.backward",
                    iconColor: .purple,
                    isOn: Binding(
                        get: { vm.settings.missedWorkoutNudgeEnabled },
                        set: { vm.settings.missedWorkoutNudgeEnabled = $0; vm.saveAndReconcile() }
                    )
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    // MARK: - Body Check Section

    private var bodyCheckSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Body Check", icon: "camera.viewfinder")

            VStack(spacing: 0) {
                settingsToggle(
                    title: "Monthly Rescan Reminder",
                    icon: "camera.fill",
                    iconColor: .teal,
                    isOn: Binding(
                        get: { vm.settings.monthlyRescanEnabled },
                        set: { vm.settings.monthlyRescanEnabled = $0; vm.saveAndReconcile() }
                    )
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Progress & Compete", icon: "trophy.fill")

            VStack(spacing: 0) {
                settingsToggle(
                    title: "Streak Alerts",
                    icon: "flame.fill",
                    iconColor: .red,
                    isOn: Binding(
                        get: { vm.settings.streakAlertsEnabled },
                        set: { vm.settings.streakAlertsEnabled = $0; vm.saveAndReconcile() }
                    )
                )

                Divider().padding(.leading, 52)

                settingsToggle(
                    title: "Challenge Reminders",
                    icon: "figure.fencing",
                    iconColor: .mint,
                    isOn: Binding(
                        get: { vm.settings.challengeReminderEnabled },
                        set: { vm.settings.challengeReminderEnabled = $0; vm.saveAndReconcile() }
                    )
                )

                Divider().padding(.leading, 52)

                settingsToggle(
                    title: "PR & Milestone Alerts",
                    icon: "medal.fill",
                    iconColor: .yellow,
                    isOn: Binding(
                        get: { vm.settings.prMilestoneReminderEnabled },
                        set: { vm.settings.prMilestoneReminderEnabled = $0; vm.saveAndReconcile() }
                    )
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    // MARK: - Lifestyle Section

    private var lifestyleSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Lifestyle", icon: "heart.fill")

            VStack(spacing: 0) {
                settingsToggle(
                    title: "Hydration Reminder",
                    icon: "drop.fill",
                    iconColor: .cyan,
                    isOn: Binding(
                        get: { vm.settings.hydrationReminderEnabled },
                        set: { vm.settings.hydrationReminderEnabled = $0; vm.saveAndReconcile() }
                    )
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                vm.sendTest()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.and.waves.left.and.right")
                        .font(.system(size: 14))
                    Text(vm.showTestSent ? "Sent!" : "Send Test Notification")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
            }

            if !vm.settings.isPaused {
                Button {
                    vm.pauseForOneWeek()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 14))
                        Text("Pause Reminders for 1 Week")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 16))
                }
            }

            Text("Fit AI sends smart reminders based on your activity. We never spam.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.bottom, 6)
    }

    private func settingsToggle(title: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(.green)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
