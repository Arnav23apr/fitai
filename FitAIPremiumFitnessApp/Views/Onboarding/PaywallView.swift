import SwiftUI
import RevenueCat
import RevenueCatUI
import StoreKit

// MARK: - PaywallView (wrapper — shows X after 4s, handles RC premium updates)

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    @State private var store = StoreViewModel.shared

    var body: some View {
        CustomPaywallView(onSubscribe: onSubscribe, onSkip: onSkip)
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

    private var lang: String { appState.profile.selectedLanguage }

    @State private var appeared:      Bool    = false
    @State private var showSkip:      Bool    = false
    @State private var isYearly:      Bool    = true
    @State private var trialEnabled:  Bool    = false
    @State private var shimmer:       CGFloat = -1
    @State private var store = StoreViewModel.shared
    @State private var shareCompleted: Bool = UserDefaults.standard.bool(forKey: "paywallShareDone")
    @State private var reviewCompleted: Bool = UserDefaults.standard.bool(forKey: "paywallReviewDone")
    @Environment(\.requestReview) private var requestReview

    // MARK: Body

    var body: some View {
        ZStack {
            Color(white: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        featuresSection
                        togglesRow
                        ctaButton
                        priceCaption
                        lifetimeCard
                        freeEarnCard
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
        .alert("Error", isPresented: .init(
            get:  { store.error != nil },
            set:  { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { Task { await store.restore() } } label: {
                Text("Restore")
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
                Text("Reach your dream physique faster.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: Features

    private let features: [(String, String)] = [
        ("camera.viewfinder",                      "Unlimited Body Scans"),
        ("figure.strengthtraining.traditional",    "AI Workout Plans"),
        ("chart.line.uptrend.xyaxis",              "Progress Analytics"),
        ("trophy.fill",                            "Leaderboards & Challenges"),
        ("bolt.fill",                              "Priority AI Coach"),
    ]

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

    // MARK: Toggles row

    private var togglesRow: some View {
        HStack(spacing: 0) {
            // Left: 2-day free trial
            HStack(spacing: 6) {
                Toggle("", isOn: $trialEnabled)
                    .labelsHidden()
                    .tint(.green)
                    .scaleEffect(0.85)
                VStack(alignment: .leading, spacing: 1) {
                    Text("2-day free")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(trialEnabled ? .white : .white.opacity(0.50))
                    Text("trial")
                        .font(.system(size: 11))
                        .foregroundStyle(trialEnabled ? .white.opacity(0.70) : .white.opacity(0.35))
                }
            }

            Spacer()

            // Right: Monthly / Yearly
            HStack(spacing: 8) {
                Text("Monthly")
                    .font(.system(size: 12, weight: isYearly ? .regular : .semibold))
                    .foregroundStyle(isYearly ? .white.opacity(0.38) : .white)
                Toggle("", isOn: $isYearly)
                    .labelsHidden()
                    .tint(.white)
                    .scaleEffect(0.85)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Yearly")
                        .font(.system(size: 12, weight: isYearly ? .semibold : .regular))
                        .foregroundStyle(isYearly ? .white : .white.opacity(0.38))
                    if isYearly {
                        Text("Save 33%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: CTA button

    private var ctaLabel: String {
        if trialEnabled { return "Start 2-Day Free Trial" }
        return "Continue"
    }

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

    // MARK: Price caption

    private var priceCaption: some View {
        Text(captionText)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.38))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.top, 10)
            .opacity(appeared ? 1 : 0)
    }

    private var captionText: String {
        if isYearly {
            let yearly = store.annualPriceString
            let monthly = store.monthlyPriceString
            if trialEnabled { return "Free for 2 days, then \(yearly)/year · Cancel anytime" }
            return "Just \(yearly)/year (\(monthly)/mo) · Cancel anytime"
        } else {
            let monthly = store.monthlyPriceString
            if trialEnabled { return "Free for 2 days, then \(monthly)/month · Cancel anytime" }
            return "Just \(monthly)/month · Cancel anytime"
        }
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
                        Text("Get Lifetime")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text("BEST VALUE")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.yellow)
                            .clipShape(.capsule)
                    }
                    Text("One payment. Train forever.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.lifetimePriceString)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                    Text("one-time")
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

    // MARK: Free Earn Card

    private var freeEarnCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("No subscription? Earn a free scan")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
            }

            VStack(spacing: 10) {
                // Step 1: Share
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(shareCompleted ? Color.green.opacity(0.20) : Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        Image(systemName: shareCompleted ? "checkmark" : "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(shareCompleted ? .green : .white.opacity(0.60))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share FitAI with 3 friends")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(shareCompleted ? .white.opacity(0.50) : .white.opacity(0.82))
                        Text("Any share counts")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                    Spacer()
                    if !shareCompleted {
                        ShareLink(
                            item: URL(string: "https://apps.apple.com/app/id6744284188")!,
                            subject: Text("Check out FitAI"),
                            message: Text("I've been using FitAI to track my fitness with AI. You should try it!")
                        ) {
                            Text("Share")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .clipShape(.capsule)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            shareCompleted = true
                            UserDefaults.standard.set(true, forKey: "paywallShareDone")
                        })
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // Step 2: Review
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(reviewCompleted ? Color.green.opacity(0.20) : Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        Image(systemName: reviewCompleted ? "checkmark" : "star.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(reviewCompleted ? .green : .white.opacity(0.60))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leave a review on the App Store")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(reviewCompleted ? .white.opacity(0.50) : .white.opacity(0.82))
                        Text("Takes 10 seconds")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                    Spacer()
                    if !reviewCompleted {
                        Button {
                            requestReview()
                            reviewCompleted = true
                            UserDefaults.standard.set(true, forKey: "paywallReviewDone")
                        } label: {
                            Text("Rate")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .clipShape(.capsule)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

            // Claim button
            if shareCompleted && reviewCompleted {
                Button {
                    appState.profile.freeScansEarned += 1
                    appState.saveProfile()
                    onSkip()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Claim 1 Free Scan")
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
        .animation(.spring(duration: 0.35), value: shareCompleted && reviewCompleted)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Legal

    private var legalText: some View {
        HStack(spacing: 4) {
            Button("Terms") {}
            Text("·").foregroundStyle(.white.opacity(0.20))
            Button("Privacy") {}
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.28))
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Purchases

    private func purchase() {
        Task {
            let pkg = isYearly ? store.annualPackage : store.monthlyPackage
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
