import SwiftUI
import UserNotifications

@Observable
@MainActor
class NotificationSettingsViewModel {
    var settings: NotificationSettings
    var systemPermissionGranted: Bool = false
    var showTestSent: Bool = false
    var showPausedConfirmation: Bool = false

    private let service = NotificationService.shared

    var reminderTime: Date {
        get {
            var components = DateComponents()
            components.hour = settings.reminderHour
            components.minute = settings.reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            settings.reminderHour = components.hour ?? 9
            settings.reminderMinute = components.minute ?? 0
            saveAndReconcile()
        }
    }

    init() {
        self.settings = NotificationService.shared.loadSettings()
        checkPermission()
    }

    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { status in
            Task { @MainActor in
                self.systemPermissionGranted = status.authorizationStatus == .authorized
            }
        }
    }

    func saveAndReconcile() {
        service.saveSettings(settings)
    }

    func reconcile(profile: UserProfile, scanHistory: [ScanHistoryEntry]) {
        service.saveSettings(settings)
        service.reconcileAll(profile: profile, scanHistory: scanHistory)
    }

    func toggleDay(_ weekday: Int) {
        if settings.workoutDays.contains(weekday) {
            settings.workoutDays.remove(weekday)
        } else {
            settings.workoutDays.insert(weekday)
        }
        saveAndReconcile()
    }

    func sendTest() {
        service.sendTestNotification()
        showTestSent = true
    }

    func pauseForOneWeek() {
        settings.pausedUntil = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        saveAndReconcile()
        showPausedConfirmation = true
    }

    func unpause() {
        settings.pausedUntil = nil
        saveAndReconcile()
    }

    var pauseLabel: String? {
        guard let pausedUntil = settings.pausedUntil, settings.isPaused else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: pausedUntil)
    }
}
