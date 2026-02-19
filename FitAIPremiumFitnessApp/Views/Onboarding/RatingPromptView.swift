import SwiftUI
import StoreKit

struct RatingPromptView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    var onContinue: () -> Void
    @State private var appeared: Bool = false
    @State private var ratingService = AppStoreRatingService.shared

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private let testimonials: [(name: String, review: String, avatarURL: String)] = [
        ("Jake Sullivan", "I gained 8 kg of muscle in 3 months! The AI coach knew exactly what I needed.", "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&h=120&fit=crop&crop=face"),
        ("Maria Lopez", "Finally an app that actually personalizes workouts. Not just random exercises.", "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&h=120&fit=crop&crop=face"),
        ("Alex Rodriguez", "The compete feature keeps me motivated every single day. Addicted!", "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&h=120&fit=crop&crop=face")
    ]

    private let peopleAvatarURLs: [String] = [
        "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&h=120&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=120&h=120&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=120&h=120&fit=crop&crop=face"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Text(L.t("giveUsRating", lang))
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 32)
                    .opacity(appeared ? 1 : 0)

                    ratingBadge
                        .opacity(appeared ? 1 : 0)

                    VStack(spacing: 8) {
                        Text(L.t("fitAIMadeForYou", lang))
                            .font(.system(.title2, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: -12) {
                            ForEach(0..<3, id: \.self) { index in
                                avatarCircle(url: peopleAvatarURLs[index])
                                    .overlay(
                                        Circle().strokeBorder(Color(.systemBackground), lineWidth: 3)
                                    )
                            }
                        }
                        .padding(.top, 8)

                        Text(L.t("millionsOfUsers", lang))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: 12) {
                        ForEach(Array(testimonials.enumerated()), id: \.offset) { index, testimonial in
                            testimonialCard(name: testimonial.name, review: testimonial.review, avatarURL: testimonial.avatarURL)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.1 + 0.3), value: appeared)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }

            VStack(spacing: 0) {
                Button(action: {
                    requestReview()
                    onContinue()
                }) {
                    Text(L.t("continue", lang))
                        .font(.headline)
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(
                Color(.systemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 12, y: -4)
                    .ignoresSafeArea()
            )
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            Task {
                await ratingService.fetchRating(appId: "6744088934")
            }
        }
    }

    private var ratingBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 24))
                .foregroundStyle(.orange)

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(ratingService.formattedRating)
                        .font(.system(.title2, design: .default, weight: .bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Text("\(ratingService.formattedCount) App Ratings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "laurel.trailing")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func avatarCircle(url: String) -> some View {
        Color(.secondarySystemBackground)
            .frame(width: 56, height: 56)
            .overlay {
                AsyncImage(url: URL(string: url)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray5)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(Circle())
    }

    private func testimonialCard(name: String, review: String, avatarURL: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Color(.secondarySystemBackground)
                    .frame(width: 40, height: 40)
                    .overlay {
                        AsyncImage(url: URL(string: avatarURL)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Text(String(name.prefix(1)))
                                    .font(.headline)
                                    .foregroundStyle(.primary.opacity(0.6))
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(Circle())

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Text(review)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(16)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
