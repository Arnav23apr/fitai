import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - PaywallView
// Always shows our custom dark paywall (premium design).
// RevenueCatUI.PaywallView is reserved for when a template is configured
// in the RC dashboard — switch the body below once that's set up.

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    @State private var store    = StoreViewModel.shared
    @State private var showSkip = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CustomPaywallView(onSubscribe: onSubscribe, onSkip: onSkip)

            if showSkip {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.60))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .padding(.top, 56)
                .padding(.trailing, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
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
    }

    private func handleSuccess(_ customerInfo: CustomerInfo) {
        if customerInfo.entitlements["Fit AI Pro"]?.isActive == true {
            appState.profile.isPremium = true
            appState.saveProfile()
            onSubscribe()
        }
    }
}

// MARK: - CustomPaywallView

private struct CustomPaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    private var lang: String { appState.profile.selectedLanguage }

    @State private var appeared:    Bool    = false
    @State private var showSkip:    Bool    = false
    @State private var selected:    PlanID  = .yearly
    @State private var store = StoreViewModel.shared
    @State private var shimmer: CGFloat     = -1

    enum PlanID { case monthly, yearly, lifetime }

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(white: 0.04), Color(white: 0.02)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    heroSection
                    featuresSection
                    planCards
                    ctaButton
                    legalText
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false).delay(0.8)) {
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
        } message: {
            Text(store.error ?? "")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restore")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
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
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Crown
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow.opacity(0.25), .clear],
                            center: .center, startRadius: 0, endRadius: 48
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.88, blue: 0.30),
                                     Color(red: 1.0, green: 0.55, blue: 0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .yellow.opacity(0.4), radius: 16, y: 4)
            }

            VStack(spacing: 8) {
                Text("FitAI Pro")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(-0.5)

                Text("Train smarter. Look better.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: Features

    private let features: [(String, String)] = [
        ("camera.viewfinder",          "Unlimited Body Scans"),
        ("figure.strengthtraining.traditional", "AI Workout Plans"),
        ("chart.line.uptrend.xyaxis",  "Progress Analytics"),
        ("trophy.fill",                "Leaderboards & Challenges"),
        ("bolt.fill",                  "Priority AI Coach"),
    ]

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 14) {
                    Image(systemName: item.0)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                    Text(item.1)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.vertical, 11)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Plan cards

    private var planCards: some View {
        VStack(spacing: 10) {
            planCard(id: .monthly,
                     title: "Monthly",
                     price: store.monthlyPriceString,
                     period: "/ month",
                     badge: nil)

            planCard(id: .yearly,
                     title: "Yearly",
                     price: store.annualPriceString,
                     period: "/ year",
                     badge: "BEST VALUE")

            planCard(id: .lifetime,
                     title: "Lifetime",
                     price: store.lifetimePriceString,
                     period: "one-time",
                     badge: nil)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
    }

    private func planCard(id: PlanID, title: String, price: String,
                          period: String, badge: String?) -> some View {
        let isSelected = selected == id
        return Button { withAnimation(.snappy(duration: 0.2)) { selected = id } } label: {
            HStack(spacing: 14) {
                // Radio
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(title)
                    .font(.system(.body, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.70))

                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.white)
                        .clipShape(.capsule)
                }

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(price)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.60))
                    Text(period)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(
                isSelected
                    ? Color.white.opacity(0.12)
                    : Color.white.opacity(0.05)
            )
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.50)
                            : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: CTA

    private var ctaButton: some View {
        Button(action: purchase) {
            ZStack {
                // Shimmer
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.10), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: shimmer * geo.size.width * 1.5)
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
        .padding(.top, 20)
        .opacity(appeared ? 1 : 0)
    }

    private var ctaLabel: String {
        switch selected {
        case .monthly:  return "Start Monthly"
        case .yearly:   return "Start Yearly"
        case .lifetime: return "Get Lifetime Access"
        }
    }

    // MARK: Legal

    private var legalText: some View {
        VStack(spacing: 6) {
            Text(selectedPriceCaption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Button("Terms") {}
                Text("·").foregroundStyle(.white.opacity(0.20))
                Button("Privacy") {}
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.30))
        }
        .padding(.horizontal, 32)
        .padding(.top, 14)
        .padding(.bottom, 36)
        .opacity(appeared ? 1 : 0)
    }

    private var selectedPriceCaption: String {
        switch selected {
        case .monthly:  return "\(store.monthlyPriceString) billed monthly · Cancel any time"
        case .yearly:   return "\(store.annualPriceString) billed annually · Cancel any time"
        case .lifetime: return "\(store.lifetimePriceString) one-time payment · No subscription"
        }
    }

    // MARK: Purchase

    private func purchase() {
        Task {
            let pkg: RevenueCat.Package? = {
                switch selected {
                case .monthly:  return store.monthlyPackage
                case .yearly:   return store.annualPackage
                case .lifetime: return store.lifetimePackage
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
