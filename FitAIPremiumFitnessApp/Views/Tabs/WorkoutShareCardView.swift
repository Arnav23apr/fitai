import SwiftUI
import MuscleMap

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
}

struct WorkoutShareCardView: View {
    let data: WorkoutShareCardData

    private let mapper = MuscleMapperService.shared

    private var volumeString: String {
        let vol = Int(data.totalVolume)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: vol)) ?? "\(vol)"
    }

    private var focusLabel: String {
        if data.focusAreas.count == 1 {
            return data.focusAreas[0]
        }
        return data.focusAreas.prefix(2).joined(separator: " & ")
    }

    private var durationString: String {
        let h = data.duration / 60
        let m = data.duration % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) min"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: data.workoutDate)
    }

    private var topSetString: String {
        guard data.topSetWeight > 0 else { return "-" }
        return "\(Int(data.topSetWeight))\(data.weightUnit) × \(data.topSetReps)"
    }

    private var primaryMuscles: [Muscle] { mapper.primaryMuscles(for: data.exercises) }
    private var secondaryMuscles: [Muscle] { mapper.secondaryMuscles(for: data.exercises) }

    private var preferredSide: BodySide {
        let frontMuscles: Set<Muscle> = [.chest, .abs, .obliques, .quadriceps, .biceps, .deltoids, .forearm]
        let frontCount = primaryMuscles.filter { frontMuscles.contains($0) }.count
            + secondaryMuscles.filter { frontMuscles.contains($0) }.count
        let backCount = (primaryMuscles.count + secondaryMuscles.count) - frontCount
        return frontCount >= backCount ? .front : .back
    }

    private let shareBodyStyle = BodyViewStyle(
        defaultFillColor: Color(white: 0.22),
        strokeColor: Color(white: 0.30),
        strokeWidth: 0.3,
        selectionColor: .red,
        selectionStrokeColor: .red,
        selectionStrokeWidth: 1.5,
        headColor: Color(white: 0.30),
        hairColor: Color(white: 0.12)
    )

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.bottom, 20)

            statGrid
                .padding(.bottom, 16)

            if data.prCount > 0 {
                prSection
                    .padding(.bottom, 16)
            }

            divider
                .padding(.bottom, 20)

            muscleMapSection
                .padding(.bottom, 20)

            brandingSection
        }
        .frame(width: 360)
        .padding(.vertical, 32)
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(data.workoutName.uppercased())
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
                .tracking(1.5)

            Text(dateString.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1)
        }
    }

    private var statGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                statCell(label: "VOLUME", value: volumeString, unit: data.weightUnit)
                statDivider
                statCell(label: "DURATION", value: durationString, unit: nil)
            }

            divider

            HStack(spacing: 0) {
                statCell(label: "TOP SET", value: topSetString, unit: nil)
                statDivider
                statCell(label: "CALORIES", value: "\(data.estimatedCalories)", unit: "kcal")
            }
        }
        .padding(.horizontal, 20)
    }

    private func statCell(label: String, value: String, unit: String?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
                .tracking(1.2)

            if let unit {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            } else {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(width: 1, height: 44)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    private var prSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))

            VStack(alignment: .leading, spacing: 2) {
                Text(data.prCount == 1 ? "New Personal Record" : "\(data.prCount) New Personal Records")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                if let firstName = data.prExerciseNames.first {
                    let extra = data.prCount > 1 ? " +\(data.prCount - 1) more" : ""
                    Text(firstName + extra)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.70))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var muscleMapSection: some View {
        VStack(spacing: 10) {
            Text("MUSCLES WORKED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
                .tracking(1.2)

            buildShareBodyView(side: preferredSide)
                .frame(height: 200)
                .shadow(color: .red.opacity(0.15), radius: 30)

            muscleLegend
        }
    }

    private func buildShareBodyView(side: BodySide) -> some View {
        var view = BodyView(gender: .male, side: side, style: shareBodyStyle)
        for muscle in primaryMuscles {
            view = view.highlight(muscle, color: .red, opacity: 0.9)
        }
        for muscle in secondaryMuscles {
            view = view.highlight(muscle, color: Color(red: 1.0, green: 0.75, blue: 0.2), opacity: 0.75)
        }
        return view
    }

    private var muscleLegend: some View {
        HStack(spacing: 20) {
            legendDot(color: .red, label: "Primary")
            legendDot(color: Color(red: 1.0, green: 0.75, blue: 0.2), label: "Secondary")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.40))
        }
    }

    private var brandingSection: some View {
        VStack(spacing: 6) {
            Image("FitAILogoWhite")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
                .opacity(0.35)
        }
    }
}

struct WorkoutShareOverlay: View {
    let data: WorkoutShareCardData
    let onDismiss: () -> Void

    @State private var cardAppeared: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 28) {
                ScrollView(showsIndicators: false) {
                    WorkoutShareCardView(data: data)
                        .scaleEffect(cardAppeared ? 1 : 0.9)
                        .opacity(cardAppeared ? 1 : 0)
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
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                cardAppeared = true
            }
        }
    }

    @MainActor
    private func shareCard() {
        let renderer = ImageRenderer(
            content: WorkoutShareCardView(data: data)
                .padding(20)
        )
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
