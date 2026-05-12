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

    /// Index into `Self.quotes`, randomized on every `.onAppear` of the profile
    /// variant so each tab-switch shows a fresh regret-framed one-liner.
    /// Seeded random on first render so the first impression is non-deterministic.
    @State private var quoteIndex: Int = Int.random(in: 0..<8)

    /// Tap-to-reveal state for the profile variant. Starts blurred each time the
    /// card appears so the reveal is a deliberate "peek at your dream body"
    /// moment. Resets on `.onDisappear` (tab switch away).
    @State private var isRevealed: Bool = false

    /// True while the full-size cinematic viewer is presented. Tap on the already-
    /// revealed image to enter; tap backdrop / close button to dismiss.
    @State private var showFullSize: Bool = false

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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentQuote.emoji)
                    .font(.system(size: 18))
                Text(currentQuote.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }

            imageBlock(height: 240)
        }
        .padding(14)
        .modifier(GradientCardBackground(tintColor: .purple, cornerRadius: 16))
        .onAppear { rotateQuote() }
        .fullScreenCover(isPresented: $showFullSize) {
            if let img = loadedImage {
                GoalProjectionFullScreenViewer(
                    image: img,
                    salutation: salutation
                ) {
                    showFullSize = false
                }
            }
        }
    }

    /// Gender-aware vocative used in the full-screen viewer's "This could be
    /// you, ___." copy. Crown above the text already gives it the regal vibe,
    /// "queen" feels natural for women; everyone else gets "bro".
    private var salutation: String {
        appState.profile.gender.lowercased() == "female" ? "queen" : "bro"
    }

    // MARK: - Rotating quote

    /// Regret/counterfactual one-liners rotated on each card appearance.
    /// Sigma/stoic energy on purpose. Tab-switching to Profile picks a fresh
    /// pairing, so the message stays sticky-but-varied across sessions.
    private struct Quote {
        let emoji: String
        let text: String
    }

    private static let quotes: [Quote] = [
        Quote(emoji: "🗿", text: "The version you keep delaying."),
        Quote(emoji: "🔱", text: "Who you become without the snooze button."),
        Quote(emoji: "💪", text: "The body you've been postponing."),
        Quote(emoji: "⚔️", text: "You, if you'd stopped putting it off."),
        Quote(emoji: "🦁", text: "The version of you that didn't quit."),
        Quote(emoji: "🏛️", text: "You at zero excuses."),
        Quote(emoji: "🔥", text: "Future you, paid in full."),
        Quote(emoji: "⚡", text: "The cut you keep cancelling."),
    ]

    private var currentQuote: Quote {
        Self.quotes[quoteIndex % Self.quotes.count]
    }

    private func rotateQuote() {
        // Pick a new index that isn't the current one so two consecutive
        // appearances never repeat the same line.
        guard Self.quotes.count > 1 else { return }
        var next = Int.random(in: 0..<Self.quotes.count)
        while next == quoteIndex { next = Int.random(in: 0..<Self.quotes.count) }
        quoteIndex = next
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
                    .blur(radius: shouldBlur ? 28 : 0)
                    .overlay {
                        if shouldBlur {
                            revealOverlay
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if shouldBlur {
                            withAnimation(.easeOut(duration: 0.45)) {
                                isRevealed = true
                            }
                        } else if context == .profile {
                            showFullSize = true
                        }
                    }
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
        .onDisappear {
            // Reset reveal so coming back to the Profile tab is a fresh peek.
            if context == .profile { isRevealed = false }
        }
    }

    /// True only for the profile variant before the user has tapped to peek.
    /// The plan-preview and pre-cancel variants always show the image flat —
    /// those moments need impact, not a guessing game.
    private var shouldBlur: Bool {
        context == .profile && !isRevealed
    }

    /// Instagram-sensitive-content style overlay shown over the blurred image.
    private var revealOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 10) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(.ultraThinMaterial, in: Circle())
                Text("Tap to peek")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Only you see this.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
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

/// Applies iOS 26's liquid-glass effect clipped to a circle, falling back to a
/// material blur on older OSes so the file still compiles & ships if someone
/// drops the deployment target.
private struct LiquidGlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        }
    }
}

/// Cinematic full-screen presentation of the goal projection. Opened by tapping
/// the (already-revealed) image on the Profile card. The blurred backdrop is
/// the image itself massively scaled and blurred so the whole screen feels
/// dipped in the user's "future you" color palette. Tap the backdrop or the
/// close button to dismiss.
private struct GoalProjectionFullScreenViewer: View {
    let image: UIImage
    /// "bro" / "queen" / whatever the caller picks based on user gender.
    /// Slotted into "This could be you, ___."
    let salutation: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Blurred backdrop, image colors bleed into the whole screen.
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .blur(radius: 60)
                .overlay(Color.black.opacity(0.45))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 32))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                    .overlay(alignment: .topTrailing) {
                        closeButton
                            .padding(12)
                    }
                    .padding(.horizontal, 20)
                    // Block the backdrop-tap from firing when the user lands on
                    // the image itself; only blank space dismisses.
                    .contentShape(Rectangle())
                    .onTapGesture { /* no-op */ }

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Text("👑")
                        .font(.system(size: 44))
                    Text("This could be you, \(salutation).")
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Stay consistent. The body's already yours, you just haven't claimed it yet.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
            }
        }
        .statusBarHidden()
    }

    /// Liquid-glass close button overlaid on the image's top-right corner.
    /// Uses iOS 26's `.glassEffect` for the proper translucent / refractive look;
    /// falls back to `.ultraThinMaterial` on older OSes so the build still ships
    /// if the deployment target is lowered later.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .modifier(LiquidGlassCircle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
