import SwiftUI
import StoreKit

struct RatingPromptView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    var onContinue: () -> Void
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private let testimonials: [(name: String, review: String)] = [
        ("Jake S.", "I gained 8 kg of muscle in 3 months! The AI coach knew exactly what I needed."),
        ("Maria L.", "Finally an app that actually personalizes workouts. Not just random exercises."),
        ("Alex R.", "The compete feature keeps me motivated every single day. Addicted!")
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
                                Circle()
                                    .fill(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                                    .frame(width: 56, height: 56)
                                    .overlay {
                                        Image(systemName: avatarIcon(for: index))
                                            .font(.system(size: 22))
                                            .foregroundStyle(.primary.opacity(0.6))
                                    }
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
                            testimonialCard(name: testimonial.name, review: testimonial.review)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                requestReview()
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
                    Text("4.8")
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
                Text(L.t("appRatingsCount", lang))
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

    private func testimonialCard(name: String, review: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(name.prefix(1)))
                            .font(.headline)
                            .foregroundStyle(.primary.opacity(0.6))
                    }

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

    private func avatarIcon(for index: Int) -> String {
        switch index {
        case 0: return "person.fill"
        case 1: return "figure.run"
        default: return "dumbbell.fill"
        }
    }
}
