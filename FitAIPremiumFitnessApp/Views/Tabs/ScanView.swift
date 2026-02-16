import SwiftUI
import PhotosUI

struct ScanView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ScanViewModel()
    @State private var showPaywall: Bool = false
    @State private var showResultsSheet: Bool = false
    @State private var showTransformationSheet: Bool = false

    var body: some View {
        NavigationStack {
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
            }
            .background(Color.black)
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
            }
            .sheet(isPresented: $showResultsSheet) {
                ScanResultsSheet(result: viewModel.analysisResult, onDismiss: {
                    showResultsSheet = false
                })
            }
            .sheet(isPresented: $showTransformationSheet) {
                TransformationSheet(
                    result: viewModel.transformationResult,
                    isGenerating: viewModel.isGeneratingTransformation,
                    onDismiss: { showTransformationSheet = false }
                )
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
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("\(appState.profile.points)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(.capsule)
        }
        .padding(.vertical, 8)
    }

    private var latestScoreCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Latest score")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(format: "%.1f", appState.profile.latestScore ?? 0.0))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 4) {
                if let date = appState.profile.lastScanDate {
                    Text(date, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text("No scan yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var readyToScanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to Scan")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Upload your physique photos for AI analysis")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }

            HStack(spacing: 12) {
                photoPickerCard(
                    title: "Front",
                    subtitle: nil,
                    image: viewModel.frontImage,
                    selection: $viewModel.frontPickerItem
                )
                photoPickerCard(
                    title: "Back",
                    subtitle: "Optional",
                    image: viewModel.backImage,
                    selection: $viewModel.backPickerItem
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
                    Text(viewModel.isAnalyzing ? "Analyzing..." : "Analyze with AI")
                    if !appState.profile.isPremium && !viewModel.isAnalyzing {
                        Text("(Pro)")
                    }
                }
                .font(.headline)
                .foregroundStyle(viewModel.frontImage != nil ? .black : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.frontImage != nil ? Color.white : Color.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(viewModel.frontImage == nil || viewModel.isAnalyzing)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isAnalyzing)

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                    Spacer()
                    Button(action: { viewModel.errorMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                    Text("Photo guidelines")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func photoPickerCard(title: String, subtitle: String?, image: UIImage?, selection: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: selection, matching: .images) {
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
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.white.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
            }
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
                            Text("90-Day Transformation")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("See your potential physique with AI")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
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
                                    Text("Tap to view full")
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
                            Text(viewModel.isGeneratingTransformation ? "Generating..." : viewModel.transformationResult != nil ? "Regenerate" : "Generate Preview")
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
            Text("Tips for a better scan")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                tipRow("Good, even lighting")
                tipRow("Neutral standing pose")
                tipRow("Torso or full body visible")
                tipRow("Plain background if possible")
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.white.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func performAnalysis() async {
        let result = await viewModel.analyzeScan(profile: appState.profile)
        if let result {
            appState.profile.latestScore = result.overallScore
            appState.profile.lastScanDate = result.date
            appState.profile.totalScans += 1
            appState.profile.weakPoints = result.weakPoints
            appState.profile.strongPoints = result.strongPoints
            appState.saveProfile()
            showResultsSheet = true
        }
    }
}

struct ScanResultsSheet: View {
    let result: ScanResult?
    let onDismiss: () -> Void
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
            .background(Color.black)
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
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
        .preferredColorScheme(.dark)
    }

    private func ratingsShareSection(_ result: ScanResult) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text("Ratings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
                        Text(savedToPhotos ? "Saved" : "Save")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .sensoryFeedback(.success, trigger: savedToPhotos)

                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                        Text("Share")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func scoreSection(_ result: ScanResult) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 10)
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
                        .foregroundStyle(.white)
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
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
            statCard(title: "Potential", value: String(format: "%.1f/10", result.potentialRating), icon: "star.fill", color: .cyan)
            statCard(title: "Muscle Mass", value: result.muscleMassRating, icon: "figure.strengthtraining.traditional", color: .blue)
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
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(value)
                .font(.caption)
                .foregroundStyle(.white)
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
                Text("Strengths")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func weaknessesSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text("Areas to Improve")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func summarySection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                Text("Summary")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text(result.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func recommendationsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text("Recommendations")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, rec in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                        Text(rec)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func scoreGradient(_ score: Double) -> [Color] {
        if score >= 7 { return [.green, .mint] }
        if score >= 5 { return [.yellow, .orange] }
        return [.orange, .red]
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 8 { return "Excellent" }
        if score >= 7 { return "Great" }
        if score >= 5.5 { return "Good" }
        if score >= 4 { return "Average" }
        return "Needs Work"
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 7 { return .green }
        if score >= 5 { return .yellow }
        return .orange
    }
}

struct TransformationSheet: View {
    let result: TransformationResult?
    let isGenerating: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isGenerating {
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text("Generating your 90-day transformation...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("This may take up to a minute")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
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
                                Text("Your 90-Day Potential")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(result.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }

                            Text("Results may vary. This is an AI-generated visualization for motivation purposes.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.25))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
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
                            .foregroundStyle(.white.opacity(0.2))
                        Text("Could not generate transformation")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
            }
            .background(Color.black)
            .navigationTitle("Transformation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
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
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
