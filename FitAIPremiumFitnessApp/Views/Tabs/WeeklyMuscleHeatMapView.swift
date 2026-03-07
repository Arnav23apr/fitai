import SwiftUI
import MuscleMap

struct WeeklyMuscleHeatMapView: View {
    let workoutLogs: [WorkoutLog]
    let exerciseLogs: [ExerciseLog]
    var onMuscleTapped: ((Muscle) -> Void)? = nil

    @State private var isExpanded: Bool = true
    @State private var appeared: Bool = false

    private let mapper = MuscleMapperService.shared

    private let darkStyle = BodyViewStyle(
        defaultFillColor: Color(white: 0.25),
        strokeColor: Color(white: 0.35),
        strokeWidth: 0.3,
        selectionColor: .orange,
        selectionStrokeColor: .orange,
        selectionStrokeWidth: 1.5,
        headColor: Color(white: 0.35),
        hairColor: Color(white: 0.15)
    )

    private var weeklyIntensities: [MuscleIntensity] {
        let calendar = Calendar.current
        let now = Date()
        let weekLogs = exerciseLogs.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }

        var muscleSets: [Muscle: Int] = [:]
        for log in weekLogs {
            let completedSets = log.sets.filter(\.isCompleted).count
            guard completedSets > 0 else { continue }
            let m = mapper.mapping(for: log.exerciseName, muscleGroup: log.muscleGroup)
            for muscle in m.primary {
                muscleSets[muscle, default: 0] += completedSets
            }
            for muscle in m.secondary {
                muscleSets[muscle, default: 0] += max(completedSets / 2, 1)
            }
        }

        guard !muscleSets.isEmpty else { return [] }
        let maxSets = Double(muscleSets.values.max() ?? 1)

        return muscleSets.map { muscle, sets in
            MuscleIntensity(
                muscle: muscle,
                intensity: min(Double(sets) / maxSets, 1.0)
            )
        }
    }

    private var totalMusclesTrained: Int {
        weeklyIntensities.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.35)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                    Text("Weekly Muscle Activity")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if totalMusclesTrained > 0 {
                        Text("\(totalMusclesTrained) muscles")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            if isExpanded {
                VStack(spacing: 14) {
                    if weeklyIntensities.isEmpty {
                        emptyState
                    } else {
                        HStack(spacing: 8) {
                            buildHeatmapBody(side: .front)
                            buildHeatmapBody(side: .back)
                        }
                        .frame(height: 220)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                        HeatmapLegendView(
                            colorScale: .workout,
                            barThickness: 10,
                            labelMin: "Light",
                            labelMax: "Heavy"
                        )
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(.rect(cornerRadius: 16))
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.2)) {
                appeared = true
            }
        }
    }

    private func buildHeatmapBody(side: BodySide) -> some View {
        var view = BodyView(gender: .male, side: side, style: darkStyle)
            .heatmap(weeklyIntensities, colorScale: .workout)
            .heatmapGradient(direction: .topToBottom, lowFactor: 0.4)
        if let callback = onMuscleTapped {
            view = view.onMuscleSelected { muscle, _ in
                callback(muscle)
            }
        }
        return view.animated(duration: 0.4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Complete workouts to see your muscle activity")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
