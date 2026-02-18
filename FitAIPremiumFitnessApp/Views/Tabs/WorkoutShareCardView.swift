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
}

struct WorkoutShareCardView: View {
    let data: WorkoutShareCardData
    @State private var appeared: Bool = false

    private var volumeString: String {
        let vol = Int(data.totalVolume)
        if vol >= 1000 {
            let formatted = NumberFormatter()
            formatted.numberStyle = .decimal
            formatted.groupingSeparator = ","
            return formatted.string(from: NSNumber(value: vol)) ?? "\(vol)"
        }
        return "\(vol)"
    }

    private var durationString: String {
        let m = data.duration
        if m >= 60 {
            return "\(m / 60)h \(m % 60)m"
        }
        return "\(m) min"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 48)

            VStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                Text("WORKOUT COMPLETE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
                .frame(height: 32)

            Text(data.workoutName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()
                .frame(height: 10)

            Text(data.focusAreas.joined(separator: " · "))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 40)

            VStack(spacing: 6) {
                Text("Total Volume")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(volumeString)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("kg")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
                .frame(height: 36)

            HStack(spacing: 0) {
                statColumn(value: durationString, label: "Duration")
                statDivider
                statColumn(value: "\(data.exercisesCompleted)/\(data.totalExercises)", label: "Exercises")
                statDivider
                statColumn(value: "\(data.totalSets)", label: "Sets")
            }
            .padding(.horizontal, 20)

            if data.prCount > 0 {
                Spacer()
                    .frame(height: 32)
                prBadge
            }

            Spacer()

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .clipShape(.rect(cornerRadius: 4))
                Text("FIT AI")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08)

                LinearGradient(
                    colors: [
                        Color.green.opacity(0.08),
                        Color.clear,
                        Color.cyan.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, Color.green.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                }
            }
        )
        .clipShape(.rect(cornerRadius: 24))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 40)
    }

    private var prBadge: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 6)
                Text(data.prCount == 1 ? "NEW PERSONAL RECORD" : "\(data.prCount) NEW PERSONAL RECORDS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                    .tracking(0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1)
                    )
            )

            if !data.prExerciseNames.isEmpty {
                VStack(spacing: 4) {
                    ForEach(data.prExerciseNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

struct WorkoutShareOverlay: View {
    let data: WorkoutShareCardData
    let onDismiss: () -> Void

    @State private var cardAppeared: Bool = false
    @State private var isSharing: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                WorkoutShareCardView(data: data)
                    .frame(width: 320, height: 520)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
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
                .frame(width: 360, height: 580)
        )
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
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
