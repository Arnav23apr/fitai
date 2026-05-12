import SwiftUI

/// Reusable row showing another user's profile summary — avatar, name,
/// username, tier/points line. Used across friend lists, request inbox,
/// search results, and challenge cards.
struct SocialProfileRow: View {
    let profile: SocialProfileSummary
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Use the photo if uploaded, else SF Symbol fallback over the
            // brand-orange tier gradient.
            if let photoURL = profile.profilePhotoURL,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        avatar
                    }
                }
                .frame(width: 40, height: 40)
                .background(tierGradient)
                .clipShape(Circle())
            } else {
                avatar
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if profile.isPremium == true {
                        proCrown
                    }
                }
                HStack(spacing: 6) {
                    Text("@\(profile.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // Tier label intentionally hidden — ranks aren't shipping in v1.
                    if let streak = profile.currentStreak, streak > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(streak)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 6)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(tierGradient)
            Image(systemName: profile.avatarSystemName ?? "person.crop.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    /// Pro crown — gold→amber gradient SF Symbol next to the name when
    /// the user has an active Fit AI Pro entitlement.
    private var proCrown: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.85, blue: 0.30),
                        Color(red: 1.00, green: 0.62, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color.orange.opacity(0.45), radius: 3)
            .accessibilityLabel("Pro member")
    }

    /// Neutral avatar gradient — ranks aren't shipping in v1, so all
    /// avatars share the same brand orange wash regardless of tier.
    private var tierGradient: LinearGradient {
        LinearGradient(
            colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.60)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
