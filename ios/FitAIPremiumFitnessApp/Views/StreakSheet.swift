import SwiftUI

struct StreakSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false
    @State private var fireScale: CGFloat = 0.6

    private var isDark: Bool { colorScheme == .dark }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var streakMessage: String {
        let streak = appState.profile.currentStreak
        if streak >= 30 { return "Unstoppable. 30+ days strong 💪" }
        if streak >= 14 { return "Two weeks of pure discipline 💪" }
        if streak >= 7 { return "A full week! Keep this energy 💪" }
        if streak >= 3 { return "Building momentum. Stay locked in 💪" }
        if streak >= 1 { return "Great start. Keep showing up 💪" }
        return "Start a streak today 💪"
    }

    var body: some View {
        VStack(spacing: 28) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(fireScale)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(appeared ? 1 : 0.6)
                }

                Text("\(appState.profile.currentStreak)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(appState.profile.currentStreak == 1 ? "Day Streak" : "Day Streak")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(streakMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            weeklyDotsSection
                .opacity(appeared ? 1 : 0)

            HStack(spacing: 0) {
                statItem(value: "\(appState.profile.totalWorkouts)", label: "Workouts", color: .blue)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 32)
                statItem(value: "\(appState.profile.points)", label: "Points", color: .yellow)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 32)
                statItem(value: appState.profile.tier, label: "Tier", color: .cyan)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                fireScale = 1.0
            }
        }
    }

    private var weeklyDotsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(appState.workoutsThisWeek)/\(appState.profile.workoutsPerWeek)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            }

            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
            let fullLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

            HStack(spacing: 0) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                    let completed = appState.isDayCompleted(fullLabels[index])
                    let isToday = index == todayIndex

                    VStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isToday ? .primary : .tertiary)

                        ZStack {
                            Circle()
                                .fill(
                                    completed ? Color.green :
                                    isToday ? Color.primary.opacity(0.12) :
                                    Color.primary.opacity(0.05)
                                )
                                .frame(width: 34, height: 34)

                            if completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isDark ? .black : .white)
                            } else if isToday {
                                Circle()
                                    .fill(Color.primary.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
