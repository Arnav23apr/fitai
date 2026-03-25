import SwiftUI

struct WorkoutResumePill: View {
    let session: WorkoutSessionManager
    let onTap: () -> Void

    @State private var pulsing: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulsing ? 1.3 : 1.0)

                Image(systemName: session.workoutIcon.isEmpty ? "dumbbell.fill" : session.workoutIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)

                Text(session.workoutName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(session.formatTime(session.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.green)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("\(session.completedCount)/\(session.totalExercises)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.elapsedSeconds)
    }
}
