import Foundation
import UserNotifications

/// Routes UNNotificationResponse taps into the right tab + (when relevant)
/// opens a specific challenge sheet.
///
/// APNs payloads carry a `kind` field set by the send_push edge function.
/// Local notifications still carry `tab` from the existing scheduler — both
/// paths flow through this delegate.
@Observable
@MainActor
class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    var tourManager: TourManager?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // Push (APNs) payloads — routed by `kind`. Falls through to legacy
        // local-notification routing if no kind is present.
        if let kind = userInfo["kind"] as? String {
            await routePushKind(kind, userInfo: userInfo)
            return
        }

        // Legacy local-notification path — `tab` index set by scheduler
        if let tab = userInfo["tab"] as? Int {
            await MainActor.run {
                self.tourManager?.selectedTab = tab
            }
        }
    }

    /// Tab indices: 0=Scan, 1=Plan, 2=Compete, 3=Profile.
    /// Keeps the mapping in one place so future kinds can be added cleanly.
    @MainActor
    private func routePushKind(_ kind: String, userInfo: [AnyHashable: Any]) async {
        switch kind {
        case "challenge_sent",
             "challenge_completed",
             "challenge_won_forfeit",
             "challenge_lost_forfeit",
             "challenge_expired",
             "pending_response":
            tourManager?.selectedTab = 2   // Compete
            if let challengeId = userInfo["challenge_id"] as? String {
                tourManager?.pendingChallengeId = challengeId
            }

        case "streak_expiring":
            tourManager?.selectedTab = 1   // Plan — they need to log a workout

        case "weekly_digest",
             "rival_of_the_week":
            tourManager?.selectedTab = 2   // Compete — show stats / leaderboard

        default:
            // Unknown kinds → land on Compete (where most social activity lives)
            tourManager?.selectedTab = 2
        }
    }
}
