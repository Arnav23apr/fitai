import SwiftUI

/// "Future you" card — displays the AI-generated goal physique projection
/// (Gemini 2.5 Flash Image, generated server-side via the
/// `generate_goal_projection` edge function).
///
/// Three contexts:
///   - `.planPreview` — onboarding plan reveal, headline-style ("Your goal")
///   - `.profile` — permanent reminder + regenerate button
///   - `.preCancel` — confirmation interstitial before opening the system
///                    manage-subscription sheet ("This is who you walk away from")
struct GoalProjectionCard: View {
    enum Context {
        case planPreview
        case profile
        case preCancel
    }

    @Environment(AppState.self) private var appState

    let context: Context

    /// Caller-supplied callback when the user taps the regenerate button.
    /// Only relevant in `.profile` context. The caller owns the actual
    /// `GoalProjectionService.generate(...)` call so it can show its own
    /// progress UI.
    var onRegenerate: (() -> Void)? = nil

    /// Caller-supplied callback for `.preCancel` "Continue with cancellation".
    /// Tapping it dismisses the confirmation and proceeds to the system
    /// manage-subscription sheet.
    var onProceedCancel: (() -> Void)? = nil

    /// Caller-supplied callback for `.preCancel` "Stay subscribed". Just
    /// dismisses the sheet.
    var onStaySubscribed: (() -> Void)? = nil

    @State private var isRegenerating: Bool = false

    private var imageURL: URL? {
        guard let s = appState.profile.goalProjectionURL,
              let url = URL(string: s) else { return nil }
        return url
    }

    private var lastGenLabel: String? {
        guard let date = appState.profile.goalProjectionGeneratedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        switch context {
        case .planPreview: planPreviewVariant
        case .profile:     profileVariant
        case .preCancel:   preCancelVariant
        }
    }

    // MARK: - Plan preview variant

    private var planPreviewVariant: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 1.0))
                Text("FUTURE YOU")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }

            imageBlock(height: 220)

            Text("This is where you're headed.")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.primary)

            Text("AI projection of your goal physique based on your scan and plan. Stay consistent and this is your 12-week target.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .modifier(GradientCardBackground(tintColor: .purple, cornerRadius: 18))
    }

    // MARK: - Profile variant

    private var profileVariant: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your goal physique")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let last = lastGenLabel {
                        Text("Updated \(last)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if onRegenerate != nil {
                    Button {
                        guard !isRegenerating else { return }
                        isRegenerating = true
                        onRegenerate?()
                        // Caller sets isRegenerating back via state ownership;
                        // we reset locally after a short window so the spinner
                        // doesn't get stuck if the parent forgets.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                            isRegenerating = false
                        }
                    } label: {
                        if isRegenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                    .disabled(isRegenerating)
                }
            }

            imageBlock(height: 240)
        }
        .padding(14)
        .modifier(GradientCardBackground(tintColor: .purple, cornerRadius: 16))
    }

    // MARK: - Pre-cancel variant

    private var preCancelVariant: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Wait.")
                    .font(.system(.largeTitle, weight: .black))
                    .foregroundStyle(.primary)
                Text("This is who you walk away from.")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            imageBlock(height: 280)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                Button {
                    onStaySubscribed?()
                } label: {
                    Text("Stay subscribed")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.primary)
                        .clipShape(.rect(cornerRadius: 27))
                }

                Button {
                    onProceedCancel?()
                } label: {
                    Text("Continue with cancellation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
    }

    // MARK: - Shared image block

    @ViewBuilder
    private func imageBlock(height: CGFloat) -> some View {
        if let url = imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder(height: height) {
                        ProgressView().controlSize(.regular)
                    }
                case .success(let img):
                    img.resizable()
                        .scaledToFill()
                case .failure:
                    placeholder(height: height) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                    }
                @unknown default:
                    placeholder(height: height) { EmptyView() }
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 14))
        } else {
            placeholder(height: height) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    VStack(spacing: 4) {
                        Text("Locked")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Run a body scan to generate your 90-day physique projection.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func placeholder<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.primary.opacity(0.05)
            content()
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 14))
    }
}
