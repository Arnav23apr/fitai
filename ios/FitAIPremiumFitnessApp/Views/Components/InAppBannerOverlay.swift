import SwiftUI

/// Top-anchored toast that drops down to surface in-app notifications
/// (incoming friend request, challenge invite, etc.) while the user is
/// browsing inside the app. Tap to dismiss; otherwise auto-dismisses on
/// the timer set by `AppState.showBanner`.
///
/// Attach as an overlay on `MainTabView` so banners ride above the tab
/// bar content but below any presented sheets / full-screen covers
/// (intentional — banners shouldn't fight a focused modal flow).
struct InAppBannerOverlay: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if let banner = appState.currentBanner {
                bannerCard(banner)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            appState.currentBanner = nil
                        }
                    }
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(appState.currentBanner != nil)
        .animation(.spring(duration: 0.4, bounce: 0.18), value: appState.currentBanner)
    }

    private func bannerCard(_ banner: InAppBanner) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(banner.iconTint.opacity(0.20))
                    .frame(width: 38, height: 38)
                Image(systemName: banner.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(banner.iconTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(banner.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.30), radius: 20, y: 8)
    }
}
