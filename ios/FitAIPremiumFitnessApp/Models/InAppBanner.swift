import SwiftUI

/// Lightweight banner payload for the toast-style notification that
/// drops down from the top of `MainTabView` when something noteworthy
/// happens (incoming friend request, challenge invite, etc.).
///
/// `id` is auto-assigned per banner instance so the auto-dismiss task in
/// `AppState.showBanner` can match-and-clear without racing against
/// subsequent banners.
struct InAppBanner: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let iconTint: Color

    static func == (lhs: InAppBanner, rhs: InAppBanner) -> Bool {
        lhs.id == rhs.id
    }
}
