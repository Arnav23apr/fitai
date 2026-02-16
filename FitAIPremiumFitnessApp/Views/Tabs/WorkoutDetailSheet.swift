import SwiftUI

struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutDay

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerCard

                    exercisesList

                    tipsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.black)
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: workout.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(workout.isWeakPointFocus ? .orange : .white)
                    .frame(width: 52, height: 52)
                    .background(
                        workout.isWeakPointFocus ?
                        Color.orange.opacity(0.12) : Color.white.opacity(0.08)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        if workout.isWeakPointFocus {
                            Text("FOCUS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(.capsule)
                        }
                    }
                    Text(workout.focusAreas.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
            }

            HStack(spacing: 0) {
                miniStat(value: "\(workout.exercises.count)", label: "Exercises")
                miniDivider
                miniStat(value: "\(totalSets)", label: "Total Sets")
                miniDivider
                miniStat(value: estimatedTime, label: "Est. Time")
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets }
    }

    private var estimatedTime: String {
        let minutes = totalSets * 3
        return "\(minutes)min"
    }

    private var exercisesList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Exercises")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                HStack(spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Text(exercise.muscleGroup)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(exercise.sets) sets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(exercise.reps)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow.opacity(0.7))
                Text("Tips")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                tipRow("Rest 60-90s between sets for hypertrophy")
                tipRow("Focus on controlled eccentric (lowering) phase")
                tipRow("Stay hydrated — aim for water between sets")
                if workout.isWeakPointFocus {
                    tipRow("Extra volume on weak points accelerates growth")
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}
