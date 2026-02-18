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
}

struct WorkoutShareCardView: View {
    let data: WorkoutShareCardData

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

    private var focusEmoji: String {
        let focus = data.focusAreas.first?.lowercased() ?? ""
        if focus.contains("chest") { return "💪" }
        if focus.contains("back") { return "🔱" }
        if focus.contains("leg") || focus.contains("glute") { return "🦵" }
        if focus.contains("shoulder") { return "🏋️" }
        if focus.contains("arm") || focus.contains("bicep") || focus.contains("tricep") { return "💪" }
        if focus.contains("core") || focus.contains("ab") { return "🔥" }
        return "💪"
    }

    private var focusLabel: String {
        if data.focusAreas.count == 1 {
            return "\(data.focusAreas[0]) Day"
        }
        return data.focusAreas.prefix(2).joined(separator: " & ") + " Day"
    }

    private var primaryMuscle: String {
        data.focusAreas.first?.lowercased() ?? "chest"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.top, 28)

            Spacer().frame(height: 28)

            volumeSection

            Spacer().frame(height: 24)

            focusSection

            Spacer().frame(height: 20)

            silhouetteSection

            if data.prCount > 0 {
                Spacer().frame(height: 20)
                prSection
            }

            Spacer().frame(height: 28)

            brandingSection
                .padding(.bottom, 24)
        }
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05), .white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("FITAI WORKOUT SUMMARY")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
            }
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var volumeSection: some View {
        VStack(spacing: 2) {
            Text("TOTAL VOLUME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(volumeString)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("kg")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text("moved today")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var focusSection: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 60, height: 1)

            HStack(spacing: 6) {
                Text("WORKOUT FOCUS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text("\(focusEmoji) \(focusLabel)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var silhouetteSection: some View {
        ZStack {
            Image(systemName: "figure.stand")
                .font(.system(size: 90, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.08))

            muscleGlow
        }
        .frame(height: 120)
    }

    @ViewBuilder
    private var muscleGlow: some View {
        let muscle = primaryMuscle
        if muscle.contains("chest") || muscle.contains("push") {
            glowDot(offset: CGSize(width: 0, height: -22), color: .cyan)
        } else if muscle.contains("back") || muscle.contains("pull") {
            glowDot(offset: CGSize(width: 0, height: -16), color: .blue)
        } else if muscle.contains("shoulder") {
            HStack(spacing: 30) {
                glowDot(offset: .zero, color: .orange)
                glowDot(offset: .zero, color: .orange)
            }
            .offset(y: -30)
        } else if muscle.contains("leg") || muscle.contains("glute") || muscle.contains("quad") {
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 14) {
                    glowDot(offset: .zero, color: .green)
                    glowDot(offset: .zero, color: .green)
                }
            }
            .offset(y: 16)
        } else if muscle.contains("arm") || muscle.contains("bicep") || muscle.contains("tricep") {
            HStack(spacing: 44) {
                glowDot(offset: .zero, color: .purple)
                glowDot(offset: .zero, color: .purple)
            }
            .offset(y: -14)
        } else if muscle.contains("core") || muscle.contains("ab") {
            glowDot(offset: CGSize(width: 0, height: 2), color: .red)
        } else {
            glowDot(offset: CGSize(width: 0, height: -10), color: .cyan)
        }
    }

    private func glowDot(offset: CGSize, color: Color) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.6), color.opacity(0.2), color.opacity(0)],
                    center: .center,
                    startRadius: 2,
                    endRadius: 28
                )
            )
            .frame(width: 56, height: 56)
            .blur(radius: 6)
            .offset(offset)
    }

    private var prSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 18))
                Text("NEW PR")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.3))
            }

            if let prName = data.prExerciseNames.first {
                Text(prName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))

                if data.prBestWeight > 0 {
                    Text("\(Int(data.prBestWeight)) kg × \(data.prBestReps)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 1, green: 0.84, blue: 0.3).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(red: 1, green: 0.84, blue: 0.3).opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private var brandingSection: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [.green, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 18, height: 18)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                }
                .clipShape(.rect(cornerRadius: 4))
            Text("FitAI")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
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

            VStack(spacing: 24) {
                WorkoutShareCardView(data: data)
                    .shadow(color: .cyan.opacity(0.15), radius: 40, y: 10)
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
