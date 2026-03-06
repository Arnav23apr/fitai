import Foundation
import UserNotifications

@Observable
@MainActor
class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    var tourManager: TourManager?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let tab = userInfo["tab"] as? Int {
            Task { @MainActor in
                self.tourManager?.selectedTab = tab
            }
        }
    }
}
