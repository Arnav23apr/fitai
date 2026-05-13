import SwiftUI
import MuscleMap

struct IdentifiableShareData: Identifiable {
    let id = UUID()
    let data: WorkoutShareCardData
}

struct PRDetail {
    let exerciseName: String
    let newWeight: Double
    let newReps: Int
    let previousWeight: Double
    let previousReps: Int
}

struct WorkoutShareCardData {
    let workoutName: String
    let focusAreas: [String]
    let totalVolume: Double
    let duration: Int
    let exercisesCompleted: Int
    let totalExercises: Int
    let totalSets: Int
    let prCount: Int
    let prExerciseNames: [String]
    let pointsEarned: Int
    let prBestWeight: Double
    let prBestReps: Int
    var weightUnit: String = "kg"
    var topSetExercise: String = ""
    var topSetWeight: Double = 0
    var topSetReps: Int = 0
    var estimatedCalories: Int = 0
    var exercises: [Exercise] = []
    var workoutDate: Date = Date()
    var prDetails: [PRDetail] = []
}

// MARK: - Workout Stat Enum

enum WorkoutStat: String, CaseIterable {
    case volume, topSet, duration, calories, exercises, sets, prs, heatmap

    var label: String {
        switch self {
        case .volume: return "Volume"
        case .topSet: return "Top Set"
        case .duration: return "Duration"
        case .calories: return "Calories"
        case .exercises: return "Exercises"
        case .sets: return "Sets"
        case .prs: return "PRs"
        case .heatmap: return "Heatmap"
        }
    }

    static let defaultOn: Set<WorkoutStat> = [.volume, .topSet, .duration, .heatmap]
}

enum PRCardElement: String, CaseIterable {
    case trophy, previousBest, workoutContext

    var label: String {
        switch self {
        case .trophy: return "Trophy"
        case .previousBest: return "Previous"
        case .workoutContext: return "Workout"
        }
    }
}

// MARK: - Stories Share Card (Strava-style, transparent background)

struct WorkoutStoriesCardView: View {
    let data: WorkoutShareCardData
    var visibleStats: Set<WorkoutStat> = WorkoutStat.defaultOn

    private let mapper = MuscleMapperService.shared

    private var volumeString: String {
        let vol = Int(data.totalVolume)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: vol)) ?? "\(vol)"
    }

    private var durationString: String {
        let h = data.duration / 60
        let m = data.duration % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m \(data.duration % 60 > 0 ? "" : "00s")"
    }

    private var topSetString: String {
        guard data.topSetWeight > 0 else { return "-" }
        return "\(Int(data.topSetWeight))\(data.weightUnit) \u{00D7} \(data.topSetReps)"
    }

    private var primaryMuscles: [Muscle] { mapper.primaryMuscles(for: data.exercises) }
    private var secondaryMuscles: [Muscle] { mapper.secondaryMuscles(for: data.exercises) }

    private var preferredSide: BodySide {
        // Defer to the shared classifier so pull days (lats + rear delts +
        // upper back) no longer get pulled toward front by the deltoids /
        // forearm wrap-around being mis-bucketed as front-only.
        MuscleMapperService.dominantSide(primary: primaryMuscles, secondary: secondaryMuscles).side
    }

    private let storiesBodyStyle = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.15),
        strokeColor: Color.white.opacity(0.20),
        strokeWidth: 0.3,
        selectionColor: .orange,
        selectionStrokeColor: .orange,
        selectionStrokeWidth: 1.5,
        headColor: Color.white.opacity(0.20),
        hairColor: Color.white.opacity(0.10)
    )

    // Stats excluding heatmap (for layout calculation)
    private var activeStats: [WorkoutStat] {
        WorkoutStat.allCases.filter { $0 != .heatmap && visibleStats.contains($0) }
    }

    private var useGrid: Bool { activeStats.count >= 4 }

    var body: some View {
        VStack(spacing: 0) {
            // Workout name badge
            Text(data.workoutName.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 24)
                .padding(.bottom, 28)

            if useGrid {
                gridStats
            } else {
                verticalStats
            }

            if visibleStats.contains(.heatmap) {
                buildStoriesBodyView(side: preferredSide)
                    .frame(height: 200)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
            }

            // Branding + scan CTA — always shown. The tagline turns
            // every shared workout into a piece of inbound
            // acquisition: the viewer's eye lands on "Scan your
            // physique in FitAI" right under the logo. Strava's
            // viral playbook ("if it's not on Strava, it didn't
            // happen") adapted to FitAI's AI-scan differentiator.
            VStack(spacing: 6) {
                Image("FitAILogoWhite")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 22)
                    .opacity(0.55)
                Text("Scan your physique in FitAI")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.bottom, 24)
        }
        .frame(width: 360)
    }

    // MARK: - Vertical Layout (1-3 stats)

    private var verticalStats: some View {
        VStack(spacing: 16) {
            ForEach(activeStats, id: \.self) { stat in
                statView(for: stat)
            }
        }
        .padding(.bottom, visibleStats.contains(.heatmap) ? 32 : 28)
    }

    // MARK: - Grid Layout (4+ stats)

    private var gridStats: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(activeStats, id: \.self) { stat in
                statView(for: stat)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, visibleStats.contains(.heatmap) ? 32 : 28)
    }

    @ViewBuilder
    private func statView(for stat: WorkoutStat) -> some View {
        switch stat {
        case .volume:
            heroStat(label: "Volume", value: volumeString, unit: data.weightUnit)
        case .topSet:
            heroStat(
                label: "Top Set",
                value: topSetString,
                unit: nil,
                subtitle: data.topSetExercise.isEmpty ? nil : data.topSetExercise
            )
        case .duration:
            heroStat(label: "Duration", value: durationString, unit: nil)
        case .calories:
            heroStat(label: "Calories", value: "\(data.estimatedCalories)", unit: "cal")
        case .exercises:
            heroStat(label: "Exercises", value: "\(data.exercisesCompleted)/\(data.totalExercises)", unit: nil)
        case .sets:
            heroStat(label: "Total Sets", value: "\(data.totalSets)", unit: nil)
        case .prs:
            heroStat(label: "PRs", value: "\(data.prCount)", unit: nil)
        case .heatmap:
            EmptyView()
        }
    }

    private func heroStat(label: String, value: String, unit: String?, subtitle: String? = nil) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            if let unit {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: useGrid ? 28 : 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: useGrid ? 12 : 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                Text(value)
                    .font(.system(size: useGrid ? 28 : 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 2)
            }
        }
    }

    private func buildStoriesBodyView(side: BodySide) -> some View {
        var view = BodyView(gender: .male, side: side, style: storiesBodyStyle)
        for muscle in primaryMuscles {
            view = view.highlight(muscle, color: .orange, opacity: 0.9)
        }
        for muscle in secondaryMuscles {
            view = view.highlight(muscle, color: .orange, opacity: 0.45)
        }
        return view
    }
}

// MARK: - PR Share Card (transparent, minimal Strava-style)

struct PRShareCardView: View {
    let data: WorkoutShareCardData
    var prDetails: [PRDetail] = []
    var showTrophy: Bool = true
    var showPreviousBest: Bool = true
    var showWorkoutContext: Bool = true

    private var displayPRs: [PRDetail] {
        if !prDetails.isEmpty { return prDetails }
        if !data.prDetails.isEmpty { return data.prDetails }
        return data.prExerciseNames.map { name in
            PRDetail(exerciseName: name, newWeight: data.prBestWeight, newReps: data.prBestReps, previousWeight: 0, previousReps: 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if showTrophy {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(displayPRs.count > 1 ? "\(displayPRs.count) PERSONAL RECORDS" : "PERSONAL RECORD")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            } else {
                Spacer().frame(height: 24)
            }

            // PR entries
            ForEach(Array(displayPRs.enumerated()), id: \.offset) { index, pr in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                }

                VStack(spacing: 6) {
                    Text(pr.exerciseName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    Text("\(Int(pr.newWeight))\(data.weightUnit) \u{00D7} \(pr.newReps)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if showPreviousBest && pr.previousWeight > 0 {
                        Text("Previous: \(Int(pr.previousWeight))\(data.weightUnit) \u{00D7} \(pr.previousReps)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 2)
                    }
                }
            }

            // Workout context
            if showWorkoutContext {
                VStack(spacing: 4) {
                    Text(data.workoutName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.3))
                    Text(data.workoutDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.top, 28)
                .padding(.bottom, 20)
            } else {
                Spacer().frame(height: 20)
            }

            // Branding + scan CTA — always shown. The tagline turns
            // every shared workout into a piece of inbound
            // acquisition: the viewer's eye lands on "Scan your
            // physique in FitAI" right under the logo. Strava's
            // viral playbook ("if it's not on Strava, it didn't
            // happen") adapted to FitAI's AI-scan differentiator.
            VStack(spacing: 6) {
                Image("FitAILogoWhite")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 22)
                    .opacity(0.55)
                Text("Scan your physique in FitAI")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.bottom, 24)
        }
        .frame(width: 360)
    }
}

// MARK: - Share Overlay

struct WorkoutShareOverlay: View {
    let data: WorkoutShareCardData
    let onDismiss: () -> Void

    // Default true so the card is visible immediately on present. Was
    // false-then-flipped-via-onAppear, but in some fullScreenCover
    // presentation flows on iOS 17+ the onAppear fires after a runloop
    // tick and the entire card stays at opacity 0 → blank screen.
    @State private var cardAppeared: Bool = true
    @State private var selectedCard: Int = 0

    // Workout card customization
    @State private var workoutStats: Set<WorkoutStat> = WorkoutStat.defaultOn

    // PR card customization
    @State private var showTrophy: Bool = true
    @State private var showPreviousBest: Bool = true
    @State private var showWorkoutContext: Bool = true

    private var hasPRs: Bool { data.prCount > 0 }

    private var effectivePRDetails: [PRDetail] {
        if !data.prDetails.isEmpty { return data.prDetails }
        return data.prExerciseNames.map { name in
            PRDetail(
                exerciseName: name,
                newWeight: data.prBestWeight,
                newReps: data.prBestReps,
                previousWeight: 0,
                previousReps: 0
            )
        }
    }

    private var availableWorkoutStats: [WorkoutStat] {
        WorkoutStat.allCases.filter { stat in
            if stat == .prs { return data.prCount > 0 }
            return true
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 12) {
                // Card type toggle (only when PRs exist)
                if hasPRs {
                    HStack(spacing: 8) {
                        cardToggleButton(title: "Workout", index: 0)
                        cardToggleButton(title: "PRs", index: 1)
                    }
                    .padding(.top, 12)
                    .opacity(cardAppeared ? 1 : 0)
                }

                // Customization chips
                customizationChips
                    .opacity(cardAppeared ? 1 : 0)

                ScrollView(showsIndicators: false) {
                    Group {
                        if selectedCard == 0 {
                            WorkoutStoriesCardView(data: data, visibleStats: workoutStats)
                        } else {
                            PRShareCardView(
                                data: data,
                                prDetails: effectivePRDetails,
                                showTrophy: showTrophy,
                                showPreviousBest: showPreviousBest,
                                showWorkoutContext: showWorkoutContext
                            )
                        }
                    }
                    .background(
                        CheckerboardBackground()
                            .clipShape(.rect(cornerRadius: 16))
                    )
                    .scaleEffect(cardAppeared ? 1 : 0.9)
                    .opacity(cardAppeared ? 1 : 0)
                    .animation(.snappy(duration: 0.3), value: selectedCard)
                    .animation(.snappy(duration: 0.25), value: workoutStats)
                    .animation(.snappy(duration: 0.25), value: showTrophy)
                    .animation(.snappy(duration: 0.25), value: showPreviousBest)
                    .animation(.snappy(duration: 0.25), value: showWorkoutContext)
                }

                HStack(spacing: 16) {
                    Button {
                        shareCard()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Share")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(.capsule)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .opacity(cardAppeared ? 1 : 0)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Customization Chips

    @ViewBuilder
    private var customizationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if selectedCard == 0 {
                    ForEach(availableWorkoutStats, id: \.self) { stat in
                        chipButton(
                            label: stat.label,
                            isActive: workoutStats.contains(stat)
                        ) {
                            withAnimation(.snappy(duration: 0.25)) {
                                if workoutStats.contains(stat) {
                                    workoutStats.remove(stat)
                                } else {
                                    workoutStats.insert(stat)
                                }
                            }
                        }
                    }
                } else {
                    chipButton(label: "Trophy", isActive: showTrophy) {
                        withAnimation(.snappy(duration: 0.25)) { showTrophy.toggle() }
                    }
                    chipButton(label: "Previous", isActive: showPreviousBest) {
                        withAnimation(.snappy(duration: 0.25)) { showPreviousBest.toggle() }
                    }
                    chipButton(label: "Workout", isActive: showWorkoutContext) {
                        withAnimation(.snappy(duration: 0.25)) { showWorkoutContext.toggle() }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chipButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.35))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private func cardToggleButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedCard = index
            }
        } label: {
            HStack(spacing: 5) {
                if index == 1 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selectedCard == index ? .white : .white.opacity(0.4))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(selectedCard == index ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(Capsule())
        }
    }

    @MainActor
    private func shareCard() {
        let content: AnyView
        if selectedCard == 0 {
            content = AnyView(WorkoutStoriesCardView(data: data, visibleStats: workoutStats).padding(20))
        } else {
            content = AnyView(PRShareCardView(
                data: data,
                prDetails: effectivePRDetails,
                showTrophy: showTrophy,
                showPreviousBest: showPreviousBest,
                showWorkoutContext: showWorkoutContext
            ).padding(20))
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        renderer.isOpaque = false

        guard let image = renderer.uiImage,
              let pngData = image.pngData(),
              let pngImage = UIImage(data: pngData) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [pngImage],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Checkerboard (transparency indicator for Stories preview)

struct CheckerboardBackground: View {
    let squareSize: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(isLight ? Color(white: 0.25) : Color(white: 0.20)))
                }
            }
        }
    }
}
