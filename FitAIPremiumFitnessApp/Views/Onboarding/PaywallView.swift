import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - PaywallView
// Full-screen paywall used in the onboarding flow.
// Uses RevenueCatUI.PaywallView (template configured in RevenueCat dashboard).
// Falls back to CustomPaywallView when RC is not configured or has no offering.

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    @State private var store = StoreViewModel.shared
    @State private var showSkip = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if Purchases.isConfigured {
                RevenueCatUI.PaywallView()
                    .onPurchaseCompleted { customerInfo in
                        handleSuccess(customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        handleSuccess(customerInfo)
                    }
                    .onPurchaseCancelled { }
                    .onPurchaseFailure { _ in }
            } else {
                CustomPaywallView(onSubscribe: onSubscribe, onSkip: onSkip)
            }

            // Delayed skip / dismiss button
            if showSkip {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
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
        let isPro = customerInfo.entitlements["Fit AI Pro"]?.isActive == true
        if isPro {
            appState.profile.isPremium = true
            appState.saveProfile()
            onSubscribe()
        }
    }
}

// MARK: - PaywallSheet
// Lightweight wrapper used in ProfileView: .sheet(isPresented:) { PaywallSheet() }

struct PaywallSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreViewModel.shared

    var body: some View {
        if Purchases.isConfigured {
            RevenueCatUI.PaywallView()
                .onPurchaseCompleted { customerInfo in
                    handleSuccess(customerInfo)
                    dismiss()
                }
                .onRestoreCompleted { customerInfo in
                    handleSuccess(customerInfo)
                    dismiss()
                }
                .onPurchaseCancelled { dismiss() }
                .onPurchaseFailure { _ in }
        } else {
            CustomPaywallView(
                onSubscribe: {
                    appState.profile.isPremium = true
                    appState.saveProfile()
                    dismiss()
                },
                onSkip: { dismiss() }
            )
            .environment(appState)
        }
    }

    private func handleSuccess(_ customerInfo: CustomerInfo) {
        if customerInfo.entitlements["Fit AI Pro"]?.isActive == true {
            appState.profile.isPremium = true
            appState.saveProfile()
        }
    }
}

// MARK: - CustomPaywallView
// Fallback paywall — shown when RevenueCat is not configured or no offering is set.

private struct CustomPaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onSubscribe: () -> Void
    var onSkip: () -> Void

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    @State private var appeared: Bool = false
    @State private var showSkip: Bool = false
    @State private var isYearly: Bool = true
    @State private var store = StoreViewModel.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                skipButton
                headerSection
                featuresSection
                planToggleSection
                ctaSection
                lifetimeCard
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
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
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
    }

    private var skipButton: some View {
        HStack {
            Button { Task { await store.restore() } } label: {
                Text("Restore")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showSkip {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
    }

    private var headerSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                )
            VStack(spacing: 8) {
                Text(L.t("unlockFitAIPro", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                Text("Reach your dream physique faster.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(appeared ? 1 : 0)
        .padding(.horizontal, 24)
    }

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(icon: "figure.run",            title: "AI Workout Plans",          subtitle: "Personalized to your goals")
            FeatureRow(icon: "camera.viewfinder",     title: "Body Composition Scans",    subtitle: "Unlimited AI-powered analysis")
            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking",    subtitle: "Detailed analytics & insights")
            FeatureRow(icon: "trophy.fill",           title: "Compete & Earn",            subtitle: "Leaderboards & challenges")
            FeatureRow(icon: "bolt.fill",             title: "Priority AI Coach",         subtitle: "Faster, smarter recommendations")
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
    }

    private var planToggleSection: some View {
        HStack(spacing: 16) {
            Spacer()
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text("Monthly")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(!isYearly ? .primary : .secondary)
                    Toggle("", isOn: $isYearly)
                        .tint(.primary)
                        .labelsHidden()
                        .scaleEffect(0.9)
                    Text("Yearly")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isYearly ? .primary : .secondary)
                }
                if isYearly {
                    Text("Save 16%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(.capsule)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .opacity(appeared ? 1 : 0)
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button(action: continuePurchase) {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(isDark ? .black : .white).scaleEffect(0.9)
                    } else {
                        Text("Continue").font(.headline)
                    }
                }
                .foregroundStyle(isDark ? .black : .white)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(isDark ? Color.white : Color.black)
                .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(store.isPurchasing)
            .padding(.horizontal, 24).padding(.top, 24)

            Text(isYearly
                 ? "Just \(store.annualPriceString)/year"
                 : "\(store.monthlyPriceString)/month")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .opacity(appeared ? 1 : 0)
    }

    private var lifetimeCard: some View {
        Button(action: purchaseLifetime) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Get Lifetime")
                            .font(.headline).foregroundStyle(.primary)
                        Text("BEST VALUE")
                            .font(.system(size: 9, weight: .black)).foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.yellow).clipShape(.capsule)
                    }
                    Text("One payment. Train forever.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.lifetimePriceString)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text("one-time").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(LinearGradient(
                colors: [Color.yellow.opacity(0.08), Color.orange.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(LinearGradient(
                    colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        }
        .disabled(store.isPurchasing)
        .opacity(appeared ? 1 : 0)
    }

    private func continuePurchase() {
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

// MARK: - FeatureRow

struct FeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.05))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
