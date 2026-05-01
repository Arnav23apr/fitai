import SwiftUI
import RevenueCat
import RevenueCatUI

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
    @State private var shimmer:       CGFloat = -1
    @State private var store = StoreViewModel.shared

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
                        togglesRow
                        ctaButton
                        priceCaption
                        testimonialStrip
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

    // MARK: Plan picker (Monthly / Yearly)

    private var togglesRow: some View {
        HStack(spacing: 8) {
            Spacer()
            Text("Monthly")
                .font(.system(size: 13, weight: isYearly ? .regular : .semibold))
                .foregroundStyle(isYearly ? .white.opacity(0.38) : .white)
            Toggle("", isOn: $isYearly)
                .labelsHidden()
                .tint(.white)
                .scaleEffect(0.85)
            VStack(alignment: .leading, spacing: 1) {
                Text("Yearly")
                    .font(.system(size: 13, weight: isYearly ? .semibold : .regular))
                    .foregroundStyle(isYearly ? .white : .white.opacity(0.38))
                if isYearly {
                    Text("Save 76%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: CTA button

    private var ctaLabel: String { "Continue" }

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
            return "Just \(yearly)/year (\(monthly)/mo) · Cancel anytime"
        } else {
            return "Just \(store.monthlyPriceString)/month · Cancel anytime"
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

    // MARK: Free Earn Card — share-with-3-friends → 1 free scan

    private var friendsJoined: Int { appState.profile.friendsReferredCount }
    private var unlockReady: Bool { friendsJoined >= 3 }

    private var shareMessage: String {
        let code = appState.profile.referralCode
        if code.isEmpty {
            return "I've been using FitAI to scan my physique with AI. You should try it!"
        }
        return "I've been using FitAI to scan my physique with AI. Use my code \(code) when you sign up — try it!"
    }

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
                        Text("Share with 3 friends")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        Text(unlockReady
                             ? "Done — claim your free scan"
                             : "\(friendsJoined)/3 friends joined")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    if !unlockReady {
                        ShareLink(
                            item: shareURL,
                            subject: Text("Check out FitAI"),
                            message: Text(shareMessage)
                        ) {
                            Text("Share")
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
            Text("4.9 · 12K+ ratings")
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

    private let compareRows: [CompareRow] = [
        CompareRow(label: "Body scans",        free: "1 free",     pro: "Unlimited",   freeIsCheck: false, proIsCheck: false),
        CompareRow(label: "AI workout plans",  free: "—",          pro: "✓",           freeIsCheck: false, proIsCheck: true),
        CompareRow(label: "Weak-point coach",  free: "—",          pro: "✓",           freeIsCheck: false, proIsCheck: true),
        CompareRow(label: "Leaderboards",      free: "—",          pro: "✓",           freeIsCheck: false, proIsCheck: true),
        CompareRow(label: "Progress analytics",free: "—",          pro: "✓",           freeIsCheck: false, proIsCheck: true),
        CompareRow(label: "1v1 battles",       free: "—",          pro: "✓",           freeIsCheck: false, proIsCheck: true)
    ]

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 70)
                Text("Pro")
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

    private let testimonials: [Testimonial] = [
        Testimonial(stars: 5, name: "Mike, 28",   quote: "Down 12 lbs in 3 weeks. The scan called out exactly what I needed."),
        Testimonial(stars: 5, name: "Jordan, 24", quote: "First time I've stuck to a plan. The AI keeps it from feeling like work."),
        Testimonial(stars: 5, name: "Alex, 26",   quote: "Hit a 30 lb bench PR in 5 weeks. Worth every cent.")
    ]

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
