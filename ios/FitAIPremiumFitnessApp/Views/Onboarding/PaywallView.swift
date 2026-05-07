import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - PaywallView (wrapper — shows X after 4s, handles RC premium updates)

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void
    /// Optional callback for the Umax-style "invite 3 friends" escape hatch.
    /// When set, the friend-invite claim button calls this instead of onSkip
    /// so the host can route the user past the spin-wheel and directly to
    /// the unlocked content. Falls back to onSkip when nil (legacy callers).
    var onUnlockedViaInvite: (() -> Void)? = nil

    @State private var store = StoreViewModel.shared

    var body: some View {
        CustomPaywallView(
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

// MARK: - CustomPaywallView

private struct CustomPaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void
    var onUnlockedViaInvite: () -> Void

    private var lang: String { appState.profile.selectedLanguage }

    enum SelectedPlan { case weekly, yearly }

    @State private var appeared:      Bool          = false
    @State private var showSkip:      Bool          = false
    @State private var selectedPlan:  SelectedPlan  = .weekly
    @State private var shimmer:       CGFloat       = -1
    @State private var store = StoreViewModel.shared

    private var isYearly: Bool { selectedPlan == .yearly }

    // MARK: Body

    var body: some View {
        ZStack {
            Color(white: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        socialProofRow
                        featuresSection
                        comparisonTable
                        planSelector
                        ctaButton
                        moneyBackLine
                        costAnchor
                        orDivider
                        freeEarnCard
                        testimonialStrip
                        lifetimeCard
                        legalText
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false).delay(0.6)) {
                shimmer = 1.0
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.spring(duration: 0.4)) { showSkip = true }
            }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium {
                appState.profile.isPremium = true
                appState.saveProfile()
                onSubscribe()
            }
        }
        .alert(L.t("errorTitle", lang), isPresented: .init(
            get:  { store.error != nil },
            set:  { if !$0 { store.error = nil } }
        )) {
            Button(L.t("ok", lang)) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { Task { await store.restore() } } label: {
                Text(L.t("restore", lang))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
            if showSkip {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.10), in: Circle())
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.yellow.opacity(0.22), .clear],
                        center: .center, startRadius: 0, endRadius: 52))
                    .frame(width: 104, height: 104)
                Image(systemName: "crown.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 1, green: 0.88, blue: 0.28),
                                 Color(red: 1, green: 0.55, blue: 0.10)],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: .yellow.opacity(0.35), radius: 18, y: 5)
            }
            VStack(spacing: 6) {
                Text("FitAI Pro")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(-0.5)
                Text(L.t("reachDreamPhysique", lang))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: Features

    private var features: [(String, String)] {
        [
            ("camera.viewfinder",                      L.t("unlimitedBodyScans", lang)),
            ("figure.strengthtraining.traditional",    L.t("aiWorkoutPlans", lang)),
            ("chart.line.uptrend.xyaxis",              L.t("progressAnalytics", lang)),
            ("trophy.fill",                            L.t("leaderboardsChallenges", lang)),
            ("bolt.fill",                              L.t("priorityAICoach", lang)),
        ]
    }

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    Image(systemName: item.0)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                    Text(item.1)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.30))
                }
                .padding(.vertical, 9)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Plan selector — stacked cards (Gravl-style), weekly default

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
                withAnimation(.spring(duration: 0.25)) { selectedPlan = .weekly }
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
                withAnimation(.spring(duration: 0.25)) { selectedPlan = .yearly }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
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
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.30), lineWidth: 1.6)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(.capsule)
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(price)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(priceUnit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected ? Color.white.opacity(0.40) : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }

    // MARK: CTA button

    private var ctaLabel: String { L.t("unlockMyResults", lang) }

    private var ctaButton: some View {
        Button(action: purchase) {
            ZStack {
                // Shimmer
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.08), .clear],
                        startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: shimmer * geo.size.width * 1.6)
                    .clipped()
                }
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.black).scaleEffect(0.9)
                    } else {
                        Text(ctaLabel)
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(.rect(cornerRadius: 28))
        }
        .disabled(store.isPurchasing)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Money-back guarantee line (replaces price caption — no trial, no
    // recurring price restatement; the plan card already carries that info)

    private var moneyBackLine: some View {
        Text(L.t("cancelAnytimeMoneyBack", lang))
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.top, 10)
            .opacity(appeared ? 1 : 0)
    }

    // MARK: "or" divider — separates the subscribe path from the
    // invite-3-friends alternative (Umax-style escape hatch that converts
    // non-payers into K-factor distribution)

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            Text(L.t("orDivider", lang))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
                .textCase(.uppercase)
                .tracking(0.6)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
    }

    // Cost-comparison anchor — frames the price against an offline
    // alternative the reader recognizes is much more expensive. Pure
    // anchoring play (Tversky/Kahneman). Subtle, low-emphasis, sits
    // under the price caption so it reads as fact, not pitch.
    private var costAnchor: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
            Text(L.t("paywallCostAnchor", lang))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
        .padding(.horizontal, 32)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Lifetime card

    private var lifetimeCard: some View {
        Button(action: purchaseLifetime) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                    Image(systemName: "infinity")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top, endPoint: .bottom))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(L.t("getLifetime", lang))
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text(L.t("bestValue", lang))
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.yellow)
                            .clipShape(.capsule)
                    }
                    Text(L.t("onePaymentTrainForever", lang))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.lifetimePriceString)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                    Text(L.t("oneTime", lang))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(16)
            .background(LinearGradient(
                colors: [Color.yellow.opacity(0.07), Color.orange.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(LinearGradient(
                    colors: [Color.yellow.opacity(0.35), Color.orange.opacity(0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        }
        .disabled(store.isPurchasing)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Free Earn Card — share-with-3-friends → 1 free scan

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

    private var freeEarnCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.t("noSubEarnFreeScan", lang))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
            }

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(unlockReady ? Color.green.opacity(0.20) : Color.white.opacity(0.06))
                            .frame(width: 40, height: 40)
                        Image(systemName: unlockReady ? "checkmark" : "person.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(unlockReady ? .green : .white.opacity(0.65))
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
                            .foregroundStyle(.white.opacity(0.45))
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
                    appState.profile.friendsReferredCount = 0  // reset for next unlock cycle
                    appState.saveProfile()
                    // Friend-invite path bypasses the spin-wheel cycle and
                    // jumps the user straight to the unlocked content
                    // (planPreview in onboarding) — Umax pattern.
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
                    .background(Color.white.opacity(0.90))
                    .clipShape(.rect(cornerRadius: 24))
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .animation(.spring(duration: 0.35), value: unlockReady)
        .opacity(appeared ? 1 : 0)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = min(1, CGFloat(friendsJoined) / 3)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(Color.white.opacity(0.85))
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(duration: 0.4), value: friendsJoined)
            }
        }
        .frame(height: 4)
    }

    private var shareURL: URL {
        let code = appState.profile.referralCode
        let base = "https://apps.apple.com/app/id6744284188"
        return URL(string: code.isEmpty ? base : "\(base)?ref=\(code)")!
    }

    // MARK: Legal

    private var legalText: some View {
        HStack(spacing: 4) {
            Link(L.t("terms", lang), destination: LegalLinks.terms)
            Text("·").foregroundStyle(.white.opacity(0.20))
            Link(L.t("privacy", lang), destination: LegalLinks.privacy)
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.28))
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Purchases

    private func purchase() {
        Task {
            let pkg: Package? = {
                switch selectedPlan {
                case .weekly: return store.weeklyPackage
                case .yearly: return store.annualPackage
                }
            }()
            guard let pkg else {
                appState.profile.isPremium = true; appState.saveProfile(); onSubscribe(); return
            }
            if await store.purchase(package: pkg) {
                appState.profile.isPremium = true; appState.saveProfile(); onSubscribe()
            }
        }
    }

    private func purchaseLifetime() {
        Task {
            guard let pkg = store.lifetimePackage else {
                appState.profile.isPremium = true; appState.saveProfile(); onSubscribe(); return
            }
            if await store.purchase(package: pkg) {
                appState.profile.isPremium = true; appState.saveProfile(); onSubscribe()
            }
        }
    }

    // MARK: - Social proof row (under hero)

    private var socialProofRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }
            }
            Text(L.t("ratingsLine", lang))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Free vs Pro comparison table

    private struct CompareRow {
        let label: String
        let free: String
        let pro: String
        let freeIsCheck: Bool
        let proIsCheck: Bool
    }

    private var compareRows: [CompareRow] {
        [
            CompareRow(label: L.t("compareBodyScans", lang),          free: L.t("compareOneFree", lang), pro: L.t("compareUnlimited", lang), freeIsCheck: false, proIsCheck: false),
            CompareRow(label: L.t("compareAIWorkoutPlans", lang),     free: "—",                          pro: "✓",                            freeIsCheck: false, proIsCheck: true),
            CompareRow(label: L.t("compareWeakPointCoach", lang),     free: "—",                          pro: "✓",                            freeIsCheck: false, proIsCheck: true),
            CompareRow(label: L.t("compareLeaderboards", lang),       free: "—",                          pro: "✓",                            freeIsCheck: false, proIsCheck: true),
            CompareRow(label: L.t("compareProgressAnalytics", lang),  free: "—",                          pro: "✓",                            freeIsCheck: false, proIsCheck: true),
            CompareRow(label: L.t("compare1v1Battles", lang),         free: "—",                          pro: "✓",                            freeIsCheck: false, proIsCheck: true),
        ]
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L.t("freeTier", lang))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 70)
                Text(L.t("proTier", lang))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 70)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)

            Divider().background(Color.white.opacity(0.08))

            ForEach(Array(compareRows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 0) {
                    Text(row.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    compareCell(text: row.free, emphasized: false)
                        .frame(width: 70)
                    compareCell(text: row.pro, emphasized: true)
                        .frame(width: 70)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 14)

                if idx < compareRows.count - 1 {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .opacity(appeared ? 1 : 0)
    }

    private func compareCell(text: String, emphasized: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: emphasized ? .heavy : .medium))
            .foregroundStyle(emphasized ? .white : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Testimonial strip (after price caption)

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

    private var testimonialStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(testimonials.enumerated()), id: \.offset) { _, t in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<t.stars, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text(t.quote)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                        Text("— \(t.name)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(14)
                    .frame(width: 240, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
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
