import SwiftUI

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
}

struct WorkoutShareCardView: View {
    let data: WorkoutShareCardData

    private var volumeString: String {
        let vol = Int(data.totalVolume)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: vol)) ?? "\(vol)"
    }

    private var focusLabel: String {
        if data.focusAreas.count == 1 {
            return "\(data.focusAreas[0]) Day"
        }
        return data.focusAreas.prefix(2).joined(separator: " & ") + " Day"
    }

    private var workoutIconName: String {
        let focus = data.focusAreas.joined(separator: " ").lowercased()
        if focus.contains("chest") || focus.contains("push") || focus.contains("bench") {
            return "WorkoutIconBench"
        }
        if focus.contains("back") || focus.contains("pull") {
            return "WorkoutIconGym"
        }
        if focus.contains("leg") || focus.contains("glute") || focus.contains("quad") || focus.contains("squat") {
            return "WorkoutIconSquat"
        }
        if focus.contains("shoulder") || focus.contains("overhead") || focus.contains("press") {
            return "WorkoutIconOverhead"
        }
        if focus.contains("arm") || focus.contains("bicep") || focus.contains("tricep") {
            return "WorkoutIconBicep"
        }
        if focus.contains("core") || focus.contains("ab") {
            return "WorkoutIconAbs"
        }
        if focus.contains("upper") {
            return "WorkoutIconDumbbell"
        }
        if focus.contains("lower") {
            return "WorkoutIconSquat"
        }
        return "WorkoutIconDumbbell"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            VStack(spacing: 4) {
                Text("Volume Lifted")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(volumeString)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                    Text(data.weightUnit)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer().frame(height: 32)

            VStack(spacing: 4) {
                Text("Workout Focus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Text(focusLabel)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            if data.prCount > 0 {
                Spacer().frame(height: 32)

                VStack(spacing: 4) {
                    Text("New PR")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    if let prName = data.prExerciseNames.first {
                        Text(prName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        if data.prBestWeight > 0 {
                            Text("\(Int(data.prBestWeight)) \(data.weightUnit) × \(data.prBestReps)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }

            Spacer().frame(height: 40)

            Image(workoutIconName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 0.55))

            Spacer().frame(height: 10)

            Image("FitAILogoWhite")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
                .opacity(0.5)

            Spacer().frame(height: 40)
        }
        .frame(width: 340)
    }
}

struct WorkoutShareOverlay: View {
    let data: WorkoutShareCardData
    let onDismiss: () -> Void

    @State private var cardAppeared: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                WorkoutShareCardView(data: data)
                    .shadow(color: .green.opacity(0.15), radius: 40, y: 10)
                    .scaleEffect(cardAppeared ? 1 : 0.85)
                    .opacity(cardAppeared ? 1 : 0)

                HStack(spacing: 16) {
                    Button {
                        shareCard()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Share to Stories")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
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
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .opacity(cardAppeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                cardAppeared = true
            }
        }
    }

    @MainActor
    private func shareCard() {
        let renderer = ImageRenderer(
            content: WorkoutShareCardView(data: data)
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
