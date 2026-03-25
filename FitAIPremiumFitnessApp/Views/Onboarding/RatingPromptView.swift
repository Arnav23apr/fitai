import SwiftUI
import StoreKit

struct RatingPromptView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    var onContinue: () -> Void
    @State private var appeared: Bool = false
    @State private var starScale: CGFloat = 0.5
    @State private var starOpacity: Double = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text(L.t("giveUsRating", lang))
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Your feedback helps us build the best fitness app for you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 60)
                    .opacity(appeared ? 1 : 0)

                    starsSection
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }

            VStack(spacing: 0) {
                Button(action: {
                    requestReview()
                    onContinue()
                }) {
                    Text("Rate FitAI ⭐️")
                        .font(.headline)
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Button(action: onContinue) {
                    Text("Maybe later")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 12)
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
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.3)) {
                starScale = 1.0
                starOpacity = 1.0
            }
        }
    }

    private var starsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(starScale)
                        .opacity(starOpacity)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.5)
                            .delay(Double(index) * 0.08 + 0.3),
                            value: starScale
                        )
                }
            }

            Text("Love FitAI? Rate us on the App Store!")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.06), Color.orange.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
        )
    }

}
