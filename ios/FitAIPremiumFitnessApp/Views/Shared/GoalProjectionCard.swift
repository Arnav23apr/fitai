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

    /// On-disk-or-network image, populated by `loadImage()` when the card appears
    /// and whenever `appState.profile.goalProjectionURL` changes. Cached bytes
    /// (see `GoalProjectionCache`) survive network blips so the user never sees
    /// "Couldn't load your projection" once a projection has loaded once.
    @State private var loadedImage: UIImage? = nil
    @State private var loadFailed: Bool = false
    @State private var isLoading: Bool = false

    private var imageURLString: String? {
        let s = appState.profile.goalProjectionURL
        return (s?.isEmpty == false) ? s : nil
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
        let userId = appState.currentUserIdPublic ?? "anon"
        let hasLocalScan = GoalProjectionCache.hasScanTransformation(userId: userId)
        let hasRemote = imageURLString != nil
        let hasAny = hasLocalScan || hasRemote

        Group {
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                failurePlaceholder(height: height)
            } else if hasAny {
                placeholder(height: height) {
                    ProgressView().controlSize(.regular)
                }
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
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 14))
        .task(id: imageURLString ?? "_local") {
            await loadImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scanTransformationGenerated)) { _ in
            Task { await loadImage() }
        }
    }

    @ViewBuilder
    private func failurePlaceholder(height: CGFloat) -> some View {
        if let onRegenerate, context == .profile {
            Button {
                guard !isRegenerating else { return }
                isRegenerating = true
                onRegenerate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    isRegenerating = false
                }
            } label: {
                failurePlaceholderBody(height: height)
            }
            .buttonStyle(.plain)
            .disabled(isRegenerating)
        } else {
            failurePlaceholderBody(height: height)
        }
    }

    @ViewBuilder
    private func failurePlaceholderBody(height: CGFloat) -> some View {
        placeholder(height: height) {
            VStack(spacing: 10) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                VStack(spacing: 2) {
                    Text("Couldn't load your projection")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if onRegenerate != nil && context == .profile {
                        Text(isRegenerating ? "Regenerating…" : "Tap to regenerate")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    /// Resolves the projection image in this order:
    ///   1. Scan-tab local transformation (most recent thing the user generated)
    ///   2. URL-keyed disk cache
    ///   3. Network fetch via `GoalProjectionCache.fetchAndStore`
    ///   4. Failure placeholder
    @MainActor
    private func loadImage() async {
        let userId = appState.currentUserIdPublic ?? "anon"

        // Prefer the locally-saved Scan transformation. This is what the
        // user generated and expects to see — we shouldn't go to the
        // network (and risk the cooldown / 404) when we already have
        // their image on disk.
        if let local = GoalProjectionCache.loadScanTransformation(userId: userId) {
            loadedImage = local
            loadFailed = false
            return
        }

        guard let urlString = imageURLString else {
            loadedImage = nil
            loadFailed = false
            return
        }

        if let cached = GoalProjectionCache.loadImage(userId: userId, expectedURL: urlString) {
            loadedImage = cached
            loadFailed = false
            return
        }

        guard !isLoading else { return }
        isLoading = true
        loadFailed = false

        let image = await GoalProjectionCache.fetchAndStore(url: urlString, userId: userId)
        isLoading = false

        if let image {
            loadedImage = image
            loadFailed = false
        } else {
            loadFailed = true
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
