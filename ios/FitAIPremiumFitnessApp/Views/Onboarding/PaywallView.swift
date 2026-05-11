import SwiftUI
import RevenueCat

// MARK: - Context

/// Where the paywall is being presented from. Drives hero subtitle, CTA
/// label, and which feature gets emphasis so each entry point reads as
/// purpose-built rather than a generic upgrade nag. Conversion lift on
/// context-aware CTAs vs single-string CTAs is well established across
/// the corpus (Cal AI, Symmetry, Pingo, etc.).
enum PaywallContext {
    /// First-time user, post-plan-loading. Personalized greeting + "start"
    /// language so it reads as completing the onboarding, not buying.
    case onboarding
    /// User just took a body scan; results render blurred. Reuses the
    /// existing "Unlock my results" string so the CTA matches the locked
    /// content the user is staring at.
    case lockedScan
    /// User tapped a premium-gated coach feature.
    case coach
    /// User opened a 1v1 battle / leaderboard challenge they can't access.
    case battle
    /// Generic upgrade from profile / settings. Softer language since
    /// there's no specific feature trigger.
    case profile

    func heroSubtitle(name: String, lang: String) -> String {
        switch self {
        case .onboarding:
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return L.t("paywallHeroOnboardingUnnamed", lang)
            }
            return String(format: L.t("paywallHeroOnboardingNamed", lang), trimmed)
        case .lockedScan: return L.t("paywallHeroLockedScan", lang)
        case .coach:      return L.t("paywallHeroCoach", lang)
        case .battle:     return L.t("paywallHeroBattle", lang)
        case .profile:    return L.t("reachDreamPhysique", lang)
        }
    }

    func ctaLabel(lang: String) -> String {
        switch self {
        case .onboarding: return L.t("paywallCtaOnboarding", lang)
        case .lockedScan: return L.t("unlockMyResults", lang)
        case .coach:      return L.t("paywallCtaCoach", lang)
        case .battle:     return L.t("paywallCtaBattle", lang)
        case .profile:    return L.t("paywallCtaProfile", lang)
        }
    }

    /// Index of the feature that gets emphasis in the bento grid. Other
    /// features render normally. -1 means no emphasis.
    var emphasisFeatureIndex: Int {
        switch self {
        case .onboarding, .profile: return -1
        case .lockedScan:           return 0  // Unlimited Body Scans
        case .coach:                return 4  // Priority AI Coach
        case .battle:               return 3  // Leaderboards & 1v1
        }
    }
}

// MARK: - Public entry: PaywallView (onboarding fullScreenCover step)

struct PaywallView: View {
    let context: PaywallContext
    var onSubscribe: () -> Void
    var onSkip: () -> Void
    var onUnlockedViaInvite: (() -> Void)?

    init(
        context: PaywallContext = .onboarding,
        onSubscribe: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onUnlockedViaInvite: (() -> Void)? = nil
    ) {
        self.context = context
        self.onSubscribe = onSubscribe
        self.onSkip = onSkip
        self.onUnlockedViaInvite = onUnlockedViaInvite
    }

    @Environment(AppState.self) private var appState
    @State private var store = StoreViewModel.shared

    var body: some View {
        PaywallContent(
            context: context,
            onSubscribe: onSubscribe,
            onSkip: onSkip,
            onUnlockedViaInvite: onUnlockedViaInvite ?? onSkip
        )
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium {
                appState.profile.isPremium = true
                appState.saveProfile()
                onSubscribe()
            }
        }
    }
}

// MARK: - Public entry: PaywallSheet (in-app sheet wrapper)

/// Sheet-presented variant. Use this anywhere a `.sheet(isPresented:)` is
/// gating premium features. Wraps `PaywallView` with dismiss-based
/// callbacks so callers don't have to wire onSubscribe/onSkip themselves.
struct PaywallSheet: View {
    let context: PaywallContext
    @Environment(\.dismiss) private var dismiss

    init(context: PaywallContext = .profile) {
        self.context = context
    }

    var body: some View {
        PaywallView(
            context: context,
            onSubscribe: { dismiss() },
            onSkip: { dismiss() }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Internal content

private enum SelectedPlan { case weekly, yearly }

private struct PaywallContent: View {
    let context: PaywallContext
    var onSubscribe: () -> Void
    var onSkip: () -> Void
    var onUnlockedViaInvite: () -> Void

    @Environment(AppState.self) private var appState
    @State private var appeared:        Bool      = false
    @State private var showSkip:        Bool      = false
    @State private var showRestore:     Bool      = false
    @State private var selectedPlan:    SelectedPlan = .weekly
    @State private var shimmer:         CGFloat   = -1
    @State private var heroPulse:       CGFloat   = 0.95
    @State private var quoteIndex:      Int       = 0
    @State private var store = StoreViewModel.shared

    private var lang: String { appState.profile.selectedLanguage }
    private var firstName: String { appState.profile.name }

    // MARK: Body

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        heroSection
                        socialProofQuote
                        featureBento
                        planSelector
                        ctaSection
                        orDivider
                        freeEarnCard
                        legalText
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startAnimations() }
        .alert(L.t("errorTitle", lang), isPresented: .init(
            get:  { store.error != nil },
            set:  { if !$0 { store.error = nil } }
        )) {
            Button(L.t("ok", lang)) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    // MARK: Animation lifecycle

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.55)) { appeared = true }
        withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false).delay(0.6)) {
            shimmer = 1.0
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            heroPulse = 1.05
        }
        // Restore button surfaces shortly after entry so it doesn't compete
        // with the first read of the value prop.
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.3)) { showRestore = true }
        }
        // Skip button on a longer delay — keeps users reading the offer.
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.spring(duration: 0.4)) { showSkip = true }
        }
        // Rotating testimonial cycle.
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeInOut(duration: 0.4)) {
                    quoteIndex = (quoteIndex + 1) % testimonials.count
                }
            }
        }
    }

    // MARK: Background

    /// Soft layered dark backdrop. A radial accent behind the hero, fading
    /// to near-black at the edges so the crown gradient reads as the
    /// visual anchor.
    private var backgroundLayer: some View {
        ZStack {
            Color(white: 0.04)
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.20).opacity(0.16),
                    Color(red: 1.0, green: 0.55, blue: 0.10).opacity(0.06),
                    .clear,
                ],
                center: .init(x: 0.5, y: 0.18),
                startRadius: 20,
                endRadius: 340
            )
        }
    }

    // MARK: Top bar (Restore + Skip)

    private var topBar: some View {
        HStack {
            if showRestore {
                Button { Task { await store.restore() } } label: {
                    Text(L.t("restore", lang))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }
                .transition(.opacity)
            }
            Spacer()
            if showSkip {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Pulsing glow halo behind the crown — gives life without
                // animating the crown itself (which would make the icon
                // feel toy-like at 46pt).
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.78, blue: 0.20).opacity(0.28),
                            Color(red: 1, green: 0.55, blue: 0.10).opacity(0.10),
                            .clear,
                        ],
                        center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                    .scaleEffect(heroPulse)
                    .blur(radius: 4)

                // Thin gold ring for definition.
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.88, blue: 0.28).opacity(0.55),
                                Color(red: 1, green: 0.55, blue: 0.10).opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.88, blue: 0.28),
                            Color(red: 1, green: 0.55, blue: 0.10),
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: .yellow.opacity(0.35), radius: 16, y: 4)
            }
            VStack(spacing: 6) {
                Text("FitAI Pro")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(-0.5)
                Text(context.heroSubtitle(name: firstName, lang: lang))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.top, 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: Social proof — single rotating quote under hero

    private struct Testimonial {
        let stars: Int
        let name: String
        let quote: String
    }

    private var testimonials: [Testimonial] {
        [
            Testimonial(stars: 5, name: "Mike, 28",   quote: L.t("testimonial1Quote", lang)),
            Testimonial(stars: 5, name: "Jordan, 24", quote: L.t("testimonial2Quote", lang)),
            Testimonial(stars: 5, name: "Alex, 26",   quote: L.t("testimonial3Quote", lang)),
        ]
    }

    private var socialProofQuote: some View {
        let t = testimonials[quoteIndex]
        return VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<t.stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }
                Text(L.t("ratingsLine", lang))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
                    .padding(.leading, 4)
            }
            Text("\"\(t.quote)\" — \(t.name)")
                .font(.system(size: 12))
                .italic()
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 28)
                .id(quoteIndex)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Feature bento (2x3 glass cards)

    private struct PaywallFeature {
        let icon: String
        let title: String
    }

    private var features: [PaywallFeature] {
        [
            PaywallFeature(icon: "camera.viewfinder",                   title: L.t("unlimitedBodyScans", lang)),
            PaywallFeature(icon: "figure.strengthtraining.traditional", title: L.t("aiWorkoutPlans", lang)),
            PaywallFeature(icon: "chart.line.uptrend.xyaxis",           title: L.t("progressAnalytics", lang)),
            PaywallFeature(icon: "trophy.fill",                         title: L.t("leaderboardsChallenges", lang)),
            PaywallFeature(icon: "bolt.fill",                           title: L.t("priorityAICoach", lang)),
            PaywallFeature(icon: "sparkles",                            title: "All Pro features"),
        ]
    }

    private var featureBento: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                featureCard(feature, emphasized: idx == context.emphasisFeatureIndex)
            }
        }
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
    }

    private func featureCard(_ feature: PaywallFeature, emphasized: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: feature.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.88, blue: 0.28),
                        Color(red: 1, green: 0.55, blue: 0.10),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(emphasized ? 0.10 : 0.06))
                )
            Text(feature.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(emphasized ? 1.0 : 0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(emphasized ? 0.07 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    emphasized
                        ? LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.78, blue: 0.20).opacity(0.55),
                                Color(red: 1, green: 0.55, blue: 0.10).opacity(0.20),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                          ),
                    lineWidth: emphasized ? 1.2 : 0.7
                )
        )
    }

    // MARK: Plan selector

    private var planSelector: some View {
        VStack(spacing: 10) {
            planCard(
                isSelected: selectedPlan == .weekly,
                title: L.t("weeklyPlan", lang),
                subtitle: L.t("billedWeekly", lang),
                price: store.weeklyPriceString,
                priceUnit: L.t("pricePerWeek", lang),
                badge: nil
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.28)) { selectedPlan = .weekly }
            }

            planCard(
                isSelected: selectedPlan == .yearly,
                title: L.t("yearlyPlan", lang),
                subtitle: String(format: L.t("billedAnnuallyAs", lang), store.annualPriceString),
                price: store.annualPriceWeeklyString,
                priceUnit: L.t("pricePerWeek", lang),
                badge: String(format: L.t("saveBadgePercent", lang), store.annualVsWeeklySavingsPercent)
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.28)) { selectedPlan = .yearly }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .opacity(appeared ? 1 : 0)
    }

    private func planCard(
        isSelected: Bool,
        title: String,
        subtitle: String,
        price: String,
        priceUnit: String,
        badge: String?
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color(red: 1, green: 0.88, blue: 0.28),
                                    Color(red: 1, green: 0.55, blue: 0.10),
                                ],
                                startPoint: .top, endPoint: .bottom)
                            : LinearGradient(
                                colors: [Color.white.opacity(0.30)],
                                startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.8
                    )
                    .frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.88, blue: 0.28),
                                Color(red: 1, green: 0.55, blue: 0.10),
                            ],
                            startPoint: .top, endPoint: .bottom))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                        .background(
                            Capsule().fill(LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .leading,
                                endPoint: .trailing))
                        )
                        .shadow(color: .green.opacity(0.35), radius: 6, y: 2)
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(price)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(priceUnit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isSelected ? 0.09 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isSelected
                        ? LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.88, blue: 0.28).opacity(0.70),
                                Color(red: 1, green: 0.55, blue: 0.10).opacity(0.35),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [Color.white.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom),
                    lineWidth: isSelected ? 1.6 : 1
                )
        )
        .shadow(color: isSelected ? .yellow.opacity(0.12) : .clear, radius: 14, y: 4)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .contentShape(Rectangle())
    }

    // MARK: CTA + trust strip

    private var ctaSection: some View {
        VStack(spacing: 10) {
            ctaButton
            trustStrip
            costAnchor
        }
        .padding(.top, 4)
        .opacity(appeared ? 1 : 0)
    }

    private var ctaButton: some View {
        Button(action: purchase) {
            ZStack {
                // Shimmer sweep over the gold gradient.
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.30), .clear],
                        startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: shimmer * geo.size.width * 1.6)
                    .clipped()
                }
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.black).scaleEffect(0.9)
                    } else {
                        Text(context.ctaLabel(lang: lang))
                            .font(.system(.headline, weight: .heavy))
                            .foregroundStyle(.black)
                            .tracking(0.2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.88, blue: 0.28),
                        Color(red: 1, green: 0.62, blue: 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 29))
            .shadow(color: Color(red: 1, green: 0.55, blue: 0.10).opacity(0.35), radius: 18, y: 8)
        }
        .disabled(store.isPurchasing)
        .padding(.horizontal, 20)
    }

    /// Single-line trust strip below CTA. Folds money-back + cancel + rating
    /// into one signal so the reader gets all three at a glance.
    private var trustStrip: some View {
        Text(L.t("paywallTrustStrip", lang))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.48))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    /// Cost anchor: frames the price against a real-world alternative.
    /// Stays subtle (low emphasis) so it reads as fact, not pitch.
    private var costAnchor: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text(L.t("paywallCostAnchor", lang))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
        .padding(.horizontal, 32)
    }

    // MARK: "Or" divider

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            Text(L.t("orDivider", lang))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .textCase(.uppercase)
                .tracking(0.6)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.horizontal, 36)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Free Earn (invite 3 friends → 1 free scan)

    private var friendsJoined: Int { appState.profile.friendsReferredCount }
    private var unlockReady: Bool { friendsJoined >= 3 }

    private var shareMessage: String {
        let code = appState.profile.referralCode
        if code.isEmpty {
            return L.t("shareMessageNoCode", lang)
        }
        return L.t("shareMessageWithCode", lang)
            .replacingOccurrences(of: "%@", with: code)
    }

    private var shareURL: URL {
        let code = appState.profile.referralCode
        let base = "https://apps.apple.com/app/id6744284188"
        return URL(string: code.isEmpty ? base : "\(base)?ref=\(code)")!
    }

    private var freeEarnCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.t("noSubEarnFreeScan", lang))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
            }

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(unlockReady ? Color.green.opacity(0.22) : Color.white.opacity(0.06))
                            .frame(width: 40, height: 40)
                        Image(systemName: unlockReady ? "checkmark" : "person.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(unlockReady ? .green : .white.opacity(0.68))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L.t("shareWith3Friends", lang))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        Text(unlockReady
                             ? L.t("doneClaimFreeScan", lang)
                             : L.t("friendsJoinedProgress", lang)
                                .replacingOccurrences(of: "%@", with: "\(friendsJoined)"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    if !unlockReady {
                        ShareLink(
                            item: shareURL,
                            subject: Text(L.t("checkOutFitAI", lang)),
                            message: Text(shareMessage)
                        ) {
                            Text(L.t("share", lang))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .clipShape(.capsule)
                        }
                    }
                }

                if !unlockReady {
                    progressBar
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

            if unlockReady {
                Button {
                    appState.profile.freeScansEarned += 1
                    appState.profile.friendsReferredCount = 0
                    appState.saveProfile()
                    onUnlockedViaInvite()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                        Text(L.t("claim1FreeScan", lang))
                            .font(.system(.subheadline, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.92))
                    .clipShape(.rect(cornerRadius: 24))
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .animation(.spring(duration: 0.35), value: unlockReady)
        .opacity(appeared ? 1 : 0)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = min(1, CGFloat(friendsJoined) / 3)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(LinearGradient(
                    colors: [Color.green, Color.mint],
                    startPoint: .leading,
                    endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(duration: 0.4), value: friendsJoined)
            }
        }
        .frame(height: 4)
    }

    // MARK: Legal

    private var legalText: some View {
        HStack(spacing: 4) {
            Link(L.t("terms", lang), destination: LegalLinks.terms)
            Text("·").foregroundStyle(.white.opacity(0.20))
            Link(L.t("privacy", lang), destination: LegalLinks.privacy)
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.32))
        .padding(.top, 12)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Purchase

    private func purchase() {
        Task {
            let pkg: Package? = {
                switch selectedPlan {
                case .weekly: return store.weeklyPackage
                case .yearly: return store.annualPackage
                }
            }()
            guard let pkg else {
                appState.profile.isPremium = true
                appState.saveProfile()
                onSubscribe()
                return
            }
            if await store.purchase(package: pkg) {
                appState.profile.isPremium = true
                appState.saveProfile()
                onSubscribe()
            }
        }
    }
}

// MARK: - FeatureRow (kept for other uses)

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.primary.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
