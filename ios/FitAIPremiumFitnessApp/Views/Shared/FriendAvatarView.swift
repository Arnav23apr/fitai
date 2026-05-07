import SwiftUI

/// Renders a friend / opponent avatar — uses their custom photo (URL into
/// the `profile_photos` Supabase Storage bucket) when present, otherwise
/// falls back to their chosen SF Symbol. Single source of truth so adding
/// avatar caching / loading shimmer later is a one-line change.
///
/// Used in the friends carousel, leaderboard rows, friend profile sheet,
/// challenge picker, and battle pre-roll.
struct FriendAvatarView: View {
    /// Public URL of the friend's custom photo. nil = SF Symbol fallback.
    let photoURL: String?
    /// SF Symbol name (e.g. "person.crop.circle.fill") used when no photo
    /// URL is available.
    let symbolName: String?
    /// Diameter in points.
    var size: CGFloat = 44
    /// SF Symbol point size (scales with `size`).
    var symbolSize: CGFloat? = nil
    /// Background tint when showing the SF Symbol fallback.
    var fallbackBackground: Color = Color(.tertiarySystemFill)
    /// Foreground color for the SF Symbol.
    var symbolColor: Color = .secondary

    var body: some View {
        if let urlString = photoURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFill()
                case .empty:
                    ProgressView().controlSize(.small)
                case .failure:
                    fallback
                @unknown default:
                    fallback
                }
            }
            .frame(width: size, height: size)
            .background(fallbackBackground)
            .clipShape(Circle())
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: symbolName ?? "person.crop.circle.fill")
            .font(.system(size: symbolSize ?? size * 0.55))
            .foregroundStyle(symbolColor)
            .frame(width: size, height: size)
            .background(fallbackBackground)
            .clipShape(Circle())
    }
}
