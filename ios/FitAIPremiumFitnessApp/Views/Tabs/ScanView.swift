import SwiftUI
import PhotosUI

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
    @State private var viewModel = ScanViewModel()
    @State private var showStreakSheet: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    @State private var showPaywall: Bool = false
    @State private var showResultsSheet: Bool = false
    @State private var showTransformationSheet: Bool = false
    @State private var showFrontSourcePicker: Bool = false
    @State private var showBackSourcePicker: Bool = false
    @State private var showFrontCamera: Bool = false
    @State private var showBackCamera: Bool = false
    @State private var showFrontPhotoPicker: Bool = false
    @State private var showBackPhotoPicker: Bool = false
    @State private var showPhotoTips: Bool = false

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
            .overlay {
                if viewModel.isAnalyzing {
                    AnalyzingOverlayView()
                        .transition(.opacity)
                        .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showResultsSheet) {
                ScanResultsSheet(result: viewModel.analysisResult, onDismiss: {
                    showResultsSheet = false
                })
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showTransformationSheet) {
                TransformationSheet(
                    result: viewModel.transformationResult,
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
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showStreakSheet) {
                StreakSheet()
                    .presentationDetents([.fraction(0.75)])
                    .presentationBackground(.ultraThinMaterial)
            }
            .onChange(of: viewModel.frontPickerItem) { _, _ in
                Task { await viewModel.loadFrontImage() }
            }
            .onChange(of: viewModel.backPickerItem) { _, _ in
                Task { await viewModel.loadBackImage() }
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
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
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
                if appState.profile.isPremium {
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
                        if !appState.profile.isPremium {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                        }
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(viewModel.isAnalyzing ? L.t("analyzing", lang) : L.t("analyzeWithAI", lang))
                    if !appState.profile.isPremium && !viewModel.isAnalyzing {
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
                    .presentationDragIndicator(.visible)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func photoSourceCard(title: String, subtitle: String?, image: UIImage?, isFront: Bool) -> some View {
        Button {
            if isFront {
                showFrontSourcePicker = true
            } else {
                showBackSourcePicker = true
            }
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
        .confirmationDialog(L.t("choosePhoto", lang), isPresented: isFront ? $showFrontSourcePicker : $showBackSourcePicker, titleVisibility: .visible) {
            Button(L.t("takePhoto", lang)) {
                if isFront {
                    showFrontCamera = true
                } else {
                    showBackCamera = true
                }
            }
            Button(L.t("chooseFromLibrary", lang)) {
                if isFront {
                    showFrontPhotoPicker = true
                } else {
                    showBackPhotoPicker = true
                }
            }
        }
        .photosPicker(isPresented: isFront ? $showFrontPhotoPicker : $showBackPhotoPicker, selection: isFront ? $viewModel.frontPickerItem : $viewModel.backPickerItem, matching: .images)
        .fullScreenCover(isPresented: isFront ? $showFrontCamera : $showBackCamera) {
            CameraProxyView { capturedImage in
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
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
                        .presentationBackground(.ultraThinMaterial)
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
    let isGenerating: Bool
    let onDismiss: () -> Void
    var onStartWorkout: (() -> Void)? = nil

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
        }
        .presentationDetents([.large])
        
    }
}

struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                PaywallView(
                    onSubscribe: {
                        appState.profile.isPremium = true
                        appState.saveProfile()
                        dismiss()
                    },
                    onSkip: {
                        dismiss()
                    }
                )
            }
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("close", appState.profile.selectedLanguage)) { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        
    }
}
