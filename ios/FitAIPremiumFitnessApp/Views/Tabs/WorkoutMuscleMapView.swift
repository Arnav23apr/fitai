import SwiftUI
import MuscleMap

struct WorkoutMuscleMapView: View {
    let exercises: [Exercise]
    var onMuscleTapped: ((Muscle) -> Void)? = nil

    private let mapper = MuscleMapperService.shared

    private var primaryMuscles: [Muscle] { mapper.primaryMuscles(for: exercises) }
    private var secondaryMuscles: [Muscle] { mapper.secondaryMuscles(for: exercises) }

    @State private var appeared: Bool = false

    private let darkStyle = BodyViewStyle(
        defaultFillColor: Color(white: 0.25),
        strokeColor: Color(white: 0.35),
        strokeWidth: 0.3,
        selectionColor: .red,
        selectionStrokeColor: .red,
        selectionStrokeWidth: 1.5,
        headColor: Color(white: 0.35),
        hairColor: Color(white: 0.15)
    )

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                Text("Muscle Map")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                buildBodyView(side: .front)
                buildBodyView(side: .back)
            }
            .frame(height: 220)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.95)

            legend
        }
        .padding(14)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(.rect(cornerRadius: 16))
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                appeared = true
            }
        }
    }

    private func buildBodyView(side: BodySide) -> some View {
        var view = BodyView(gender: .male, side: side, style: darkStyle)
        for muscle in primaryMuscles {
            view = view.highlight(muscle, color: .red, opacity: 0.9)
        }
        for muscle in secondaryMuscles {
            view = view.highlight(muscle, color: Color(red: 1.0, green: 0.75, blue: 0.2), opacity: 0.75)
        }
        if let callback = onMuscleTapped {
            view = view.onMuscleSelected { muscle, _ in
                callback(muscle)
            }
        }
        return view.animated(duration: 0.4)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .red, label: "Primary")
            legendItem(color: Color(red: 1.0, green: 0.75, blue: 0.2), label: "Secondary")
            legendItem(color: Color(white: 0.25), label: "Untargeted")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
