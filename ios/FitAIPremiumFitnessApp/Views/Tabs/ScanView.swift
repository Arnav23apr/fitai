import SwiftUI
import StoreKit
import RevenueCat

private extension View {
    @ViewBuilder
    func streakGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.primary)
        }
    }
}

struct ScanView: View {
    @Environment(AppState.self) private var appState
    @Environment(TourManager.self) private var tourManager
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel = ScanViewModel()
    @State private var showStreakSheet: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    @State private var showPaywall: Bool = false
    @State private var showResultsSheet: Bool = false
    @State private var showTransformationSheet: Bool = false
    @State private var showFrontCamera: Bool = false
    @State private var showBackCamera: Bool = false
    @State private var showPhotoTips: Bool = false
    @State private var showLatestResult: Bool = false
    @State private var showPhotoConsent: Bool = false
    /// Set when the user taps a photo card before granting consent. The
    /// consent sheet's onResult opens this camera once the user accepts.
    @State private var pendingCameraIsFront: Bool? = nil
    /// Surfaced when a free user upgrades but their original scan photo
    /// is no longer in memory (e.g. they killed the app between the fake
    /// scan and completing the paywall). The locked results sheet
    /// dismisses and this alert tells them to retake the photo.
    @State private var showRescanRequiredAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerSection
                        latestScoreCard
                        readyToScanCard
                        transformationCard
                        tipsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                    .tourAutoScroll(tab: 0, proxy: scrollProxy)
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.isAnalyzing },
                set: { _ in /* dismissal is driven by the view model */ }
            )) {
                AnalyzingOverlayView()
                    .interactiveDismissDisabled()
                    .presentationBackground(.black)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet(context: .profile)
            }
            .sheet(isPresented: $showPhotoConsent) {
                PhotoConsentSheet { accepted in
                    guard accepted, let isFront = pendingCameraIsFront else { return }
                    if isFront { showFrontCamera = true } else { showBackCamera = true }
                    pendingCameraIsFront = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showResultsSheet) {
                ScanResultsSheet(result: viewModel.analysisResult, onDismiss: {
                    showResultsSheet = false
                })
            }
            .sheet(isPresented: $showTransformationSheet) {
                TransformationSheet(
                    result: viewModel.transformationResult,
                    currentPhoto: viewModel.analysisResult?.frontPhoto ?? viewModel.frontImage,
                    potentialRating: viewModel.analysisResult?.potentialRating,
                    isGenerating: viewModel.isGeneratingTransformation,
                    onDismiss: { showTransformationSheet = false },
                    onStartWorkout: {
                        showTransformationSheet = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            tourManager.selectedTab = 1
                        }
                    }
                )
                // Black bg lets the AnalyzingOverlayView's loader fill the
                // sheet edge to edge during generation. Once the result
                // lands, the inner content has its own backgrounds so the
                // black is just a neutral canvas behind the photo card.
                .presentationBackground(.black)
            }
            .sheet(isPresented: $showStreakSheet) {
                StreakSheet()
                    .presentationDetents([.fraction(0.75)])
            }
            .sheet(isPresented: $showLatestResult) {
                if let entry = appState.scanHistory.first {
                    ScanResultsSheet(
                        result: ScanResult(
                            date: entry.date,
                            overallScore: entry.overallScore,
                            strongPoints: entry.strongPoints,
                            weakPoints: entry.weakPoints,
                            summary: entry.summary,
                            recommendations: entry.recommendations,
                            potentialRating: entry.potentialRating,
                            muscleMassRating: entry.muscleMassRating,
                            muscleScores: entry.muscleScores.toMuscleScores(),
                            visibleMuscleGroups: entry.strongPoints + entry.weakPoints
                        ),
                        onDismiss: { showLatestResult = false }
                    )
                }
            }
            .onChange(of: appState.profile.isPremium) { _, isPremium in
                handlePremiumUpgradeWhileLocked(isPremium: isPremium)
            }
            .alert("Take a fresh photo", isPresented: $showRescanRequiredAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your photo was cleared. Take it again and we'll show your real results.")
            }
        }
    }

    /// When the user upgrades to Pro from the locked results sheet, swap
    /// the blurred placeholder for a real AI scan using the photo they
    /// already captured. The existing `AnalyzingOverlayView` fullScreenCover
    /// surfaces automatically because `viewModel.analyzeScan` flips
    /// `isAnalyzing` to true; once it returns, `viewModel.analysisResult`
    /// is replaced with the unlocked result and the open results sheet
    /// re-renders without blur.
    ///
    /// Photo-missing case: if the user killed the app between the fake
    /// scan and the purchase, `viewModel.frontImage` is nil and we can't
    /// re-run the scan silently. Dismiss the locked results sheet and ask
    /// them to retake the photo.
    private func handlePremiumUpgradeWhileLocked(isPremium: Bool) {
        guard isPremium,
              viewModel.analysisResult?.isLocked == true
        else { return }

        if viewModel.frontImage != nil {
            Task {
                let result = await viewModel.analyzeScan(profile: appState.profile)
                if let result, !result.isLocked {
                    appState.saveScanResult(result)
                    if let photo = result.frontPhoto,
                       let data = photo.jpegData(compressionQuality: 0.85) {
                        appState.saveBattlePhoto(data)
                    }
                }
            }
        } else {
            showResultsSheet = false
            showRescanRequiredAlert = true
        }
    }

    private var headerSection: some View {
        HStack {
            // Same wordmark lockup as the Welcome screen: SF dumbbell glyph
            // + "FitAI" as one word, no container. Scaled up from the
            // welcome bar's 12/18pt to match this header's .title2 scale.
            // Dropped the rounded-square "FitAILogo" asset (the scanning-
            // brackets metaphor read as camera/scan, not fitness).
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.primary)
                Text("FitAI")
                    .font(.system(.title2, weight: .black))
                    .tracking(-0.3)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button { showStreakSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("\(appState.profile.currentStreak)")
                }
                .font(.subheadline.weight(.semibold))
            }
            .streakGlassButton()
        }
        .padding(.vertical, 8)
    }

    private var latestScoreCard: some View {
        Button {
            if !appState.scanHistory.isEmpty {
                showLatestResult = true
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("latestScore", lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", appState.profile.latestScore ?? 0.0))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                HStack(spacing: 4) {
                    if let date = appState.profile.lastScanDate {
                        Text(date, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L.t("noScanYet", lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(20)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.cyan.opacity(0.06), .blue.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [.cyan.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var readyToScanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("readyToScan", lang))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(L.t("uploadPhotos", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .tourAnchor(.scanReadyCard)

            HStack(spacing: 12) {
                photoSourceCard(
                    title: L.t("front", lang),
                    subtitle: nil,
                    image: viewModel.frontImage,
                    isFront: true
                )
                photoSourceCard(
                    title: L.t("back", lang),
                    subtitle: L.t("optional", lang),
                    image: viewModel.backImage,
                    isFront: false
                )
            }

            Button(action: {
                // Everyone can run the scan now. Free users get a locked
                // (blurred) result with an unlock CTA; we don't actually
                // call the AI on their photo so there's no cost to letting
                // them through.
                Task { await performAnalysis() }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isAnalyzing {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(viewModel.isAnalyzing ? L.t("analyzing", lang) : L.t("analyzeWithAI", lang))
                }
                .font(.headline)
                .foregroundStyle(viewModel.frontImage != nil ? Color(.systemBackground) : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.frontImage != nil ? Color.primary : Color.primary.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(viewModel.frontImage == nil || viewModel.isAnalyzing)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isAnalyzing)
            .tourAnchor(.scanAnalyzeButton)

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button(action: { viewModel.errorMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button(action: { showPhotoTips = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                    Text(L.t("photoGuidelines", lang))
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .tourAnchor(.scanPhotoGuidelines)
            .sheet(isPresented: $showPhotoTips) {
                PhotoTipsSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.green.opacity(0.04), .cyan.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [.green.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    /// Gate camera launch on the photo-consent modal (GDPR Art. 9(2)(a)).
    /// First-time users see the consent sheet; once granted (and the
    /// version hasn't bumped) we go straight to the camera.
    private func requestCamera(isFront: Bool) {
        if appState.profile.hasGrantedPhotoConsent {
            if isFront { showFrontCamera = true } else { showBackCamera = true }
            return
        }
        pendingCameraIsFront = isFront
        showPhotoConsent = true
    }

    private func photoSourceCard(title: String, subtitle: String?, image: UIImage?, isFront: Bool) -> some View {
        // Outer is a tap-gesture container instead of a Button so we can
        // safely place a real Button (the remove-X) on top without nested-
        // Button hit-testing weirdness. The X needs higher precedence so it
        // takes the tap over the open-camera action of the surrounding card.
        VStack(spacing: 0) {
            if let image {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(alignment: .topLeading) {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                if isFront {
                                    viewModel.frontImage = nil
                                } else {
                                    viewModel.backImage = nil
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(.black.opacity(0.65))
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                            .padding(8)
                    }
                    .overlay(alignment: .bottom) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .clipShape(.capsule)
                            .padding(.bottom, 8)
                    }
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.7))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                )
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            requestCamera(isFront: isFront)
        }
        .fullScreenCover(isPresented: isFront ? $showFrontCamera : $showBackCamera) {
            ScanCameraView(label: title) { capturedImage in
                if isFront {
                    viewModel.frontImage = capturedImage
                } else {
                    viewModel.backImage = capturedImage
                }
            }
            .ignoresSafeArea()
        }
    }

    private var transformationCard: some View {
        Group {
            if viewModel.frontImage != nil {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("ninetyDayTransformation", lang))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(L.t("seePotentialPhysique", lang))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if let transformation = viewModel.transformationResult {
                        Button(action: { showTransformationSheet = true }) {
                            Color(.secondarySystemBackground)
                                .frame(height: 200)
                                .overlay {
                                    Image(uiImage: transformation.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .allowsHitTesting(false)
                                }
                                .clipShape(.rect(cornerRadius: 12))
                                .overlay(alignment: .bottomLeading) {
                                    Text(L.t("tapToViewFull", lang))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.black.opacity(0.6))
                                        .clipShape(.capsule)
                                        .padding(10)
                                }
                        }
                    }

                    Button(action: {
                        if appState.profile.isPremium {
                            showTransformationSheet = true
                            Task { await viewModel.generateTransformation(profile: appState.profile, userId: appState.currentUserIdPublic) }
                        } else {
                            showPaywall = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isGeneratingTransformation {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                            }
                            Text(viewModel.isGeneratingTransformation ? L.t("generating", lang) : viewModel.transformationResult != nil ? L.t("regenerate", lang) : L.t("generatePreview", lang))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .blue.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(viewModel.isGeneratingTransformation)
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.06), Color.blue.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(colors: [.purple.opacity(0.15), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
            }
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("tipsForBetterScan", lang))
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                tipRow(L.t("goodLighting", lang))
                tipRow(L.t("neutralPose", lang))
                tipRow(L.t("torsoVisible", lang))
                tipRow(L.t("plainBackground", lang))
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [.yellow.opacity(0.04), .orange.opacity(0.02), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [.yellow.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(.tertiaryLabel))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func performAnalysis() async {
        // Free users get the animation but no AI call. We show a locked
        // placeholder that the results sheet renders blurred behind a paywall.
        // Premium users get the real analysis.
        let result: ScanResult?
        if appState.profile.isPremium {
            result = await viewModel.analyzeScan(profile: appState.profile)
        } else {
            result = await viewModel.analyzeScanLocked(profile: appState.profile)
        }
        guard let result else { return }

        // Only save real (unlocked) scans to history. Locked placeholders are
        // ephemeral; the user re-scans after upgrading.
        if !result.isLocked {
            appState.saveScanResult(result)
            // Stash the front photo as the battle default so when the user
            // opens compete, their scan photo is already there. No need to
            // upload a separate photo for battles.
            if let photo = result.frontPhoto, let data = photo.jpegData(compressionQuality: 0.85) {
                appState.saveBattlePhoto(data)
            }
            requestReviewAfterFirstScan()
        }
        showResultsSheet = true
    }

    /// Fire SKStoreReviewController after the user's first completed scan —
    /// the verified value moment. Guarded by a UserDefaults flag so we only
    /// burn one of Apple's three yearly prompts on this trigger. Delayed
    /// briefly so the results sheet animates in first; the prompt then
    /// surfaces over a moment of peak satisfaction (just got their score).
    private func requestReviewAfterFirstScan() {
        let key = "didRequestReviewAfterFirstScan"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            requestReview()
        }
    }
}

struct ScanResultsSheet: View {
    @Environment(AppState.self) private var appState
    let result: ScanResult?
    let onDismiss: () -> Void

    private var lang: String { appState.profile.selectedLanguage }
    @State private var appeared: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var savedToPhotos: Bool = false
    @State private var showRatingsCard: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let result {
                    VStack(spacing: 22) {
                        if result.visibleMuscleGroups.count < 3 && !result.isLocked {
                            limitedScanBanner(visibleCount: result.visibleMuscleGroups.count)
                        }
                        ShareCardView(result: result,
                                      gender: appState.profile.gender,
                                      dateOfBirth: appState.profile.dateOfBirth)
                        geneticCeilingCard(result)
                        projectionCard(result)
                        distributionCard(result)
                        if !result.strongPoints.isEmpty || !result.weakPoints.isEmpty {
                            strengthsWeaknessesCard(result)
                        }
                        actionPlanCard(result)

                        if appState.scanHistory.count > 1 && !result.isLocked {
                            historyMiniChart
                        }

                        footerActions(result)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    // Locked results render with surgical blur on score
                    // numbers + recommendations (handled inside ShareCardView
                    // and actionPlanCard via result.isLocked). Photo, muscle
                    // labels, and overall page structure stay visible. A
                    // sticky CTA at the bottom drives the unlock.
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("results", lang))
            .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang), action: onDismiss)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if result?.isLocked != true {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let result, !result.isLocked,
                   let image = ShareCardRenderer.render(result: result, gender: appState.profile.gender) {
                    ShareSheetView(image: image)
                }
            }
            .sheet(isPresented: $showRatingsCard) {
                if let result, !result.isLocked {
                    RatingsCardSheet(result: result)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet(context: .lockedScan)
            }
            .safeAreaInset(edge: .bottom) {
                if result?.isLocked == true {
                    lockedFooterCTA
                }
            }
        }
        .presentationDetents([.large])

    }

    // MARK: - Locked-result sticky footer CTA (free-tier)

    private var lockedFooterCTA: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Pro unlocks your real score, weak points, and action plan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: { showPaywall = true }) {
                Text("Unlock my results")
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .clipShape(.rect(cornerRadius: 26))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            // hairline divider so the footer reads as a separate surface
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
    }


    // MARK: - Limited-scan banner

    /// Shown above the score card when the AI returned fewer than 3 visible
    /// muscle groups. Gendered copy: shirtless + shorts for males, fitted
    /// athletic top + leggings for females. The Retake button dismisses the
    /// results sheet, returning the user to the scan upload UI where they
    /// can take new photos.
    private func limitedScanBanner(visibleCount: Int) -> some View {
        let g = appState.profile.gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"
        let attireGuidance = isFemale
            ? "For accurate scoring, retake in a sports bra or fitted athletic top."
            : "For accurate scoring, retake shirtless and in shorts."

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                Text("Limited scan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Text("Only \(visibleCount) muscle group\(visibleCount == 1 ? "" : "s") visible in your photos. \(attireGuidance)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Retake")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.orange)
                .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.10))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Action plan

    // MARK: - Genetic Ceiling card (potential delta with arrow)

    private func geneticCeilingCard(_ result: ScanResult) -> some View {
        let current = Int(round(result.overallScore * 10))
        let ceiling = Int(round(result.potentialRating * 10))
        let delta = max(0, ceiling - current)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Text("GENETIC CEILING")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.primary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(current)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.55))
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("\(ceiling)")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .mint],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("+\(delta)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .clipShape(.capsule)
            }
            .blur(radius: result.isLocked ? 10 : 0)

            // Progress bar showing how far you are from your ceiling
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [.green, .mint],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * CGFloat(current) / 100))
                }
            }
            .frame(height: 6)

            Text("You're \(percentToCeiling(current: current, ceiling: ceiling))% of the way to your physical ceiling.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .blur(radius: result.isLocked ? 5 : 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func percentToCeiling(current: Int, ceiling: Int) -> Int {
        guard ceiling > 0 else { return 0 }
        return Int(round(Double(current) / Double(ceiling) * 100))
    }

    // MARK: - 12-week Projection card

    private func projectionCard(_ result: ScanResult) -> some View {
        let current = result.overallScore
        let ceiling = result.potentialRating
        // Simple growth model: in 12 weeks of consistent training focused
        // on weak points, a user can realistically close ~15% of the gap
        // to their ceiling. Capped so the projection never claims more
        // than +1.5 in 12 weeks (would be unrealistic).
        let gap = max(0, ceiling - current)
        let projected = min(ceiling, current + min(1.5, gap * 0.15 + 0.4))
        let projectedScaled = Int(round(projected * 10))
        let currentScaled = Int(round(current * 10))
        let focusList = result.weakPoints.prefix(3).map { $0.capitalized }.joined(separator: ", ")
        let focusText = focusList.isEmpty ? "consistent training" : focusList

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Text("12-WEEK PROJECTION")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("If you focus on \(focusText), your physique score could reach")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blur(radius: result.isLocked ? 5 : 0)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(projectedScaled)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("/100  in 12 weeks")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .blur(radius: result.isLocked ? 10 : 0)
                Text("That's +\(projectedScaled - currentScaled) from where you are today.")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .blur(radius: result.isLocked ? 6 : 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Distribution / "where you stand" card

    private func distributionCard(_ result: ScanResult) -> some View {
        let pct = PercentileBenchmark.percentile(for: result.overallScore)
        let topPct = PercentileBenchmark.topPercent(for: result.overallScore)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Text("WHERE YOU STAND")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.primary)
                Spacer()
                Text("top \(topPct)%")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .clipShape(.capsule)
                    .blur(radius: result.isLocked ? 7 : 0)
            }

            // Bell curve with marker
            BellCurveView(percentile: pct)
                .frame(height: 80)
                .blur(radius: result.isLocked ? 10 : 0)

            HStack {
                Text("novice")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("average")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("elite")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Strengths & Weaknesses card

    private func strengthsWeaknessesCard(_ result: ScanResult) -> some View {
        VStack(spacing: 14) {
            if !result.strongPoints.isEmpty {
                pointsSection(
                    title: "STRENGTHS",
                    points: result.strongPoints,
                    accent: .green,
                    icon: "checkmark.circle.fill",
                    isLocked: result.isLocked
                )
            }
            if !result.weakPoints.isEmpty {
                pointsSection(
                    title: "WEAK POINTS",
                    points: result.weakPoints,
                    accent: .orange,
                    icon: "exclamationmark.triangle.fill",
                    isLocked: result.isLocked
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func pointsSection(title: String, points: [String], accent: Color,
                               icon: String, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.primary)
            }
            // Wrapping pill row of muscle names. Pills stay visible when
            // locked so structure reads, but the names themselves blur so
            // a free user can't see whether THEIR weak point is legs vs back.
            FlowLayout(spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    pointPill(name: point, accent: accent)
                        .blur(radius: isLocked ? 6 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pointPill(name: String, accent: Color) -> some View {
        Text(name.capitalized)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accent.opacity(0.12))
            .clipShape(.capsule)
    }

    private func actionPlanCard(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Text("YOUR NEXT 3 MOVES")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(result.recommendations.prefix(3).enumerated()), id: \.offset) { _, rec in
                    actionPlanRow(text: rec, isLocked: result.isLocked)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func actionPlanRow(text: String, isLocked: Bool = false) -> some View {
        let accent = actionAccent(for: text)
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: actionIcon(for: text))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: isLocked ? 6 : 0)
        }
    }

    /// Auto-infer an SF Symbol icon for a recommendation based on keywords.
    /// Cheap heuristic — matches the rough verb/topic of each rec line.
    private func actionIcon(for text: String) -> String {
        let s = text.lowercased()
        if s.contains("protein") || s.contains("nutrition") || s.contains("diet") || s.contains("eat") || s.contains("calorie") || s.contains("food") || s.contains("meal") {
            return "fork.knife"
        }
        if s.contains("sleep") || s.contains("rest") || s.contains("recover") {
            return "bed.double.fill"
        }
        if s.contains("cardio") || s.contains("run") || s.contains("walk") {
            return "figure.run"
        }
        if s.contains("water") || s.contains("hydrat") {
            return "drop.fill"
        }
        if s.contains("form") || s.contains("posture") || s.contains("technique") {
            return "figure.mind.and.body"
        }
        if s.contains("set") || s.contains("rep") || s.contains("volume") {
            return "list.bullet.rectangle"
        }
        return "figure.strengthtraining.traditional"
    }

    private func actionAccent(for text: String) -> Color {
        let s = text.lowercased()
        if s.contains("protein") || s.contains("nutrition") || s.contains("diet") || s.contains("eat") || s.contains("calorie") || s.contains("food") || s.contains("meal") {
            return .green
        }
        if s.contains("sleep") || s.contains("rest") || s.contains("recover") {
            return .indigo
        }
        if s.contains("cardio") || s.contains("run") || s.contains("walk") {
            return .red
        }
        if s.contains("water") || s.contains("hydrat") {
            return .cyan
        }
        return .blue
    }

    // MARK: - History (demoted, inline)

    private var historyMiniChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCORE OVER TIME")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            ScanHistoryGraphView(entries: appState.scanHistory)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer actions

    private func footerActions(_ result: ScanResult) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                if let image = ShareCardRenderer.render(result: result, gender: appState.profile.gender) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    savedToPhotos = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                        .font(.system(size: 14))
                    Text(savedToPhotos ? L.t("saved", lang) : L.t("save", lang))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.primary.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
            }
            .sensoryFeedback(.success, trigger: savedToPhotos)

            Button(action: { showShareSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                    Text(L.t("share", lang))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.primary)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func scoreGradient(_ score: Double) -> [Color] {
        if score >= 7 { return [.green, .mint] }
        if score >= 5 { return [.yellow, .orange] }
        return [.orange, .red]
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 8 { return L.t("excellent", lang) }
        if score >= 7 { return L.t("great", lang) }
        if score >= 5.5 { return L.t("good", lang) }
        if score >= 4 { return L.t("average", lang) }
        return L.t("needsWork", lang)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return .yellow }
        return .orange
    }
}

// MARK: - Bell curve visualization for the distribution card.

/// Simple bell curve drawn as a stylized normal-ish path. The user's
/// percentile (0-100) maps to a marker x-position. Not a real PDF, just
/// a visual cue, "where do I stand vs. the bell".
struct BellCurveView: View {
    let percentile: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Bell shape via a quadratic curve. Sample N points.
            let path = Path { p in
                let steps = 60
                p.move(to: CGPoint(x: 0, y: h))
                for i in 0...steps {
                    let x = CGFloat(i) / CGFloat(steps) * w
                    // Bell: y = h * (1 - exp(-((x - cx)/sigma)^2))
                    let cx = w / 2
                    let sigma = w / 4
                    let dx = (x - cx) / sigma
                    let y = h - h * 0.85 * exp(-dx * dx)
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }

            let markerX = CGFloat(percentile) / 100 * w
            // Marker height: track the curve at this x so the dot sits on
            // the curve, not floating above it.
            let cx = w / 2
            let sigma = w / 4
            let dx = (markerX - cx) / sigma
            let curveY = h - h * 0.85 * exp(-dx * dx)

            ZStack {
                path
                    .fill(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.18),
                                     Color.primary.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                path
                    .stroke(Color.primary.opacity(0.30), lineWidth: 1)

                // Vertical reference line at the marker
                Path { p in
                    p.move(to: CGPoint(x: markerX, y: curveY))
                    p.addLine(to: CGPoint(x: markerX, y: h))
                }
                .stroke(Color.green, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                // Marker dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .position(x: markerX, y: curveY)

                // "you" label above marker
                Text("you")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .clipShape(.capsule)
                    .position(x: markerX,
                              y: max(8, curveY - 14))
            }
        }
    }
}

struct TransformationSheet: View {
    @Environment(AppState.self) private var appState
    let result: TransformationResult?
    var currentPhoto: UIImage? = nil
    var potentialRating: Double? = nil
    let isGenerating: Bool
    let onDismiss: () -> Void
    var onStartWorkout: (() -> Void)? = nil

    @State private var shareItem: TransformationShareItem? = nil
    @State private var isPreparingShare: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isGenerating {
                    // Full-bleed analyzing overlay (same shell as scan +
                    // battle). The sheet's `.presentationBackground(.black)`
                    // below extends the loader's vibe to the sheet edges.
                    AnalyzingOverlayView(mode: .transformation)
                } else if let result {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            Color.clear
                                .aspectRatio(3/4, contentMode: .fit)
                                .overlay {
                                    Image(uiImage: result.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .allowsHitTesting(false)
                                }
                                .clipShape(.rect(cornerRadius: 16))
                                .shadow(color: .purple.opacity(0.2), radius: 20, y: 10)

                            VStack(spacing: 8) {
                                Text(L.t("your90DayPotential", lang))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(result.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            Text(L.t("resultsDisclaimer", lang))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            shareButton(transformedImage: result.image)

                            if let onStartWorkout {
                                Button(action: onStartWorkout) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "figure.run")
                                            .font(.system(size: 14))
                                        Text("Start Your Workout")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(.rect(cornerRadius: 14))
                                }
                                .sensoryFeedback(.impact(weight: .medium), trigger: true)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text(L.t("couldNotGenerate", lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("transformation", lang))
            .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang), action: onDismiss)
                        .foregroundStyle(.primary)
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityShareSheet(activityItems: [item.image])
            }
        }
        .presentationDetents([.large])
    }

    /// Renders the diptych share card off-screen and presents the system
    /// share sheet so the user can post to Stories / iMessage / etc.
    @ViewBuilder
    private func shareButton(transformedImage: UIImage) -> some View {
        Button {
            isPreparingShare = true
            Task { @MainActor in
                let card = TransformationShareCardView.render(
                    currentPhoto: currentPhoto,
                    transformedPhoto: transformedImage,
                    potentialRating: potentialRating
                )
                isPreparingShare = false
                if let card { shareItem = TransformationShareItem(image: card) }
            }
        } label: {
            HStack(spacing: 8) {
                if isPreparingShare {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isPreparingShare ? "Preparing…" : "Share")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(colors: [.black, .gray.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isPreparingShare)
    }
}

private struct TransformationShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
