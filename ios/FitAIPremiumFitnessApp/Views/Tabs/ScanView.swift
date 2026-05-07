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
                PaywallSheet()
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
        }
    }

    private var headerSection: some View {
        HStack {
            HStack(spacing: 10) {
                Image("FitAILogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Fit AI")
                    .font(.title2.weight(.bold))
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
                if appState.profile.canScanFree {
                    Task { await performAnalysis() }
                } else {
                    showPaywall = true
                }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isAnalyzing {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                    } else {
                        if !appState.profile.canScanFree {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                        }
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(viewModel.isAnalyzing ? L.t("analyzing", lang) : L.t("analyzeWithAI", lang))
                    if !appState.profile.canScanFree && !viewModel.isAnalyzing {
                        Text(L.t("pro", lang))
                    }
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
        Button {
            requestCamera(isFront: isFront)
        } label: {
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
                            Task { await viewModel.generateTransformation(profile: appState.profile) }
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
        let result = await viewModel.analyzeScan(profile: appState.profile)
        if let result {
            appState.saveScanResult(result)
            showResultsSheet = true
            requestReviewAfterFirstScan()
        }
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

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let result {
                    VStack(spacing: 20) {
                        scoreSection(result)

                        if appState.scanHistory.count > 1 {
                            ScanHistoryGraphView(entries: appState.scanHistory)
                        }

                        bodyCompositionSection(result)
                        strengthsSection(result)
                        weaknessesSection(result)
                        summarySection(result)
                        recommendationsSection(result)

                        ratingsShareSection(result)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
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
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let result, let image = ShareCardRenderer.render(result: result) {
                    ShareSheetView(image: image)
                }
            }
            .sheet(isPresented: $showRatingsCard) {
                if let result {
                    RatingsCardSheet(result: result)
                }
            }
        }
        .presentationDetents([.large])
        
    }

    private func ratingsShareSection(_ result: ScanResult) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text(L.t("ratings", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            ShareCardView(result: result)

            HStack(spacing: 12) {
                Button(action: {
                    if let image = ShareCardRenderer.render(result: result) {
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
                    .background(Color.primary.opacity(0.1))
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
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func scoreSection(_ result: ScanResult) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: result.overallScore / 10)
                    .stroke(
                        LinearGradient(colors: scoreGradient(result.overallScore), startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", result.overallScore))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(scoreLabel(result.overallScore))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scoreColor(result.overallScore))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func bodyCompositionSection(_ result: ScanResult) -> some View {
        HStack(spacing: 12) {
            statCard(title: L.t("potential", lang), value: String(format: "%.1f/10", result.potentialRating), icon: "star.fill", color: .cyan)
            statCard(title: L.t("muscleMass", lang), value: result.muscleMassRating, icon: "figure.strengthtraining.traditional", color: .blue)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func strengthsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text(L.t("strengths", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            FlowLayout(spacing: 8) {
                ForEach(result.strongPoints, id: \.self) { point in
                    Text(point)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func weaknessesSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text(L.t("areasToImprove", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.weakPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func summarySection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                Text(L.t("summary", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Text(result.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func recommendationsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text(L.t("recommendations", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, rec in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Circle())
                        Text(rec)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
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
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text(L.t("generatingTransformation", lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(L.t("mayTakeMinute", lang))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
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

struct PaywallSheet: View {
    enum SelectedPlan { case weekly, yearly }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false
    @State private var crownScale: CGFloat = 0.6
    @State private var selectedPlan: SelectedPlan = .weekly
    @State private var store = StoreViewModel.shared

    private var lang: String { appState.profile.selectedLanguage }
    private var isYearly: Bool { selectedPlan == .yearly }

    private let features: [(icon: String, title: String)] = [
        ("camera.viewfinder", "Unlimited Scans"),
        ("figure.strengthtraining.traditional", "AI Workouts"),
        ("chart.line.uptrend.xyaxis", "Analytics"),
        ("trophy.fill", "Leaderboards"),
        ("bolt.fill", "AI Coach"),
        ("sparkles", "All Features"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroSection
                    featuresCard
                    planSelector
                    ctaButton
                    moneyBackLine
                    orDivider
                    freeEarnCard
                    lifetimeCard
                    footer
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                crownScale = 1.0
            }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium {
                appState.profile.isPremium = true
                appState.saveProfile()
                dismiss()
            }
        }
        .alert("Error", isPresented: .init(
            get:  { store.error != nil },
            set:  { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.25), .orange.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(crownScale)

                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(appeared ? 1 : 0.6)
            }

            Text("FitAI Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Reach your dream physique faster.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Features

    private var featuresCard: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(features, id: \.icon) { feature in
                VStack(spacing: 8) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 36, height: 36)
                        .background(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        .clipShape(.rect(cornerRadius: 10))

                    Text(feature.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Plan Selector — stacked cards (weekly default, yearly with dynamic SAVE % badge)

    private var planSelector: some View {
        VStack(spacing: 10) {
            planCard(
                isSelected: selectedPlan == .weekly,
                title: "Weekly",
                subtitle: "Billed weekly",
                price: store.weeklyPriceString,
                priceUnit: "/wk",
                badge: nil
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.25)) { selectedPlan = .weekly }
            }

            planCard(
                isSelected: selectedPlan == .yearly,
                title: "Yearly",
                subtitle: "Billed annually as \(store.annualPriceString)",
                price: store.annualPriceWeeklyString,
                priceUnit: "/wk",
                badge: "SAVE \(store.annualVsWeeklySavingsPercent)%"
            )
            .onTapGesture {
                withAnimation(.spring(duration: 0.25)) { selectedPlan = .yearly }
            }
        }
        .padding(.horizontal, 20)
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
                    .strokeBorder(isSelected ? Color.primary : Color.secondary.opacity(0.40), lineWidth: 1.6)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(.capsule)
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text(priceUnit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected
                        ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.primary.opacity(0.10)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: purchase) {
            Group {
                if store.isPurchasing {
                    ProgressView()
                        .tint(Color(.systemBackground))
                        .scaleEffect(0.9)
                } else {
                    Text("Get Pro Access")
                        .font(.headline)
                }
            }
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primary)
            .clipShape(.rect(cornerRadius: 28))
        }
        .disabled(store.isPurchasing)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Money-back guarantee line (replaces price restating caption)

    private var moneyBackLine: some View {
        Text("Cancel anytime · 30-day money-back guarantee")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
    }

    // MARK: - "or" divider — separates subscribe from invite-friends path

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.secondary.opacity(0.20))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)
            Rectangle()
                .fill(Color.secondary.opacity(0.20))
                .frame(height: 1)
        }
        .padding(.horizontal, 36)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Lifetime

    private var lifetimeCard: some View {
        Button(action: purchaseLifetime) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "infinity")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Lifetime")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("BEST VALUE")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color(.systemBackground))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(.capsule)
                    }
                    Text("One payment. Train forever.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.lifetimePriceString)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("one-time")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.30), Color.orange.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Free Earn — share-with-3-friends → 1 free scan

    private var friendsJoined: Int { appState.profile.friendsReferredCount }
    private var unlockReady: Bool { friendsJoined >= 3 }

    private var shareMessage: String {
        let code = appState.profile.referralCode
        if code.isEmpty {
            return "I've been using FitAI to scan my physique with AI. You should try it!"
        }
        return "I've been using FitAI to scan my physique with AI. Use my code \(code) when you sign up — try it!"
    }

    private var shareURL: URL {
        let code = appState.profile.referralCode
        let base = "https://apps.apple.com/app/id6744284188"
        return URL(string: code.isEmpty ? base : "\(base)?ref=\(code)")!
    }

    private var freeEarnCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Earn a free scan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
            }

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(unlockReady ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                            .frame(width: 40, height: 40)
                        Image(systemName: unlockReady ? "checkmark" : "person.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(unlockReady ? .green : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Share with 3 friends")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(unlockReady
                             ? "Done — claim your free scan"
                             : "\(friendsJoined)/3 friends joined")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
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
                                .foregroundStyle(Color(.systemBackground))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.primary)
                                .clipShape(.capsule)
                        }
                    }
                }

                if !unlockReady {
                    GeometryReader { geo in
                        let progress = min(1, CGFloat(friendsJoined) / 3)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule().fill(Color.primary.opacity(0.85))
                                .frame(width: geo.size.width * progress)
                                .animation(.spring(duration: 0.4), value: friendsJoined)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))

            if unlockReady {
                Button {
                    appState.profile.freeScansEarned += 1
                    appState.profile.friendsReferredCount = 0
                    appState.saveProfile()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Claim 1 Free Scan")
                            .font(.system(.subheadline, weight: .bold))
                    }
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.green)
                    .clipShape(.rect(cornerRadius: 24))
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(duration: 0.35), value: unlockReady)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Button("Terms") {}
                Text("·").foregroundStyle(.tertiary)
                Button("Privacy") {}
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Actions

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
                dismiss()
                return
            }
            if await store.purchase(package: pkg) {
                appState.profile.isPremium = true
                appState.saveProfile()
                dismiss()
            }
        }
    }

    private func purchaseLifetime() {
        Task {
            guard let pkg = store.lifetimePackage else {
                appState.profile.isPremium = true
                appState.saveProfile()
                dismiss()
                return
            }
            if await store.purchase(package: pkg) {
                appState.profile.isPremium = true
                appState.saveProfile()
                dismiss()
            }
        }
    }
}
