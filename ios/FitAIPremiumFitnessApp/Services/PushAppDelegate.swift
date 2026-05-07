import UIKit

/// Minimal UIApplicationDelegate wired in via @UIApplicationDelegateAdaptor —
/// SwiftUI doesn't expose APNs registration callbacks, so we bridge through
/// here and forward to PushNotificationService.
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushNotificationService.shared.handleRegistration(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationService.shared.handleRegistrationFailure(error)
    }
}
