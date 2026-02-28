import SwiftUI

struct FocusAreaDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let area: String
    let priority: FocusAreaPriority
    let score: Double
    let exercises: [String]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    scoreSection
                    whySection
                    exercisesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(area)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [priority.color.opacity(0.3), priority.color.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: iconForArea(area))
                    .font(.system(size: 38))
                    .foregroundStyle(priority.color)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 6) {
                Text(area)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Image(systemName: priority.icon)
                        .font(.system(size: 11))
                    Text(priority.label)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(priority.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(priority.color.opacity(0.15))
                .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var scoreSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Score")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.1f/10", score))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(priority.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [priority.color, priority.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * (score / 10.0), 0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("Why This Matters")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(whyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text("Recommended Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                HStack(spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())

                    Text(exercise)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.8))

                    Spacer()
                }
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var whyText: String {
        let lower = area.lowercased()
        if lower.contains("shoulder") || lower.contains("delt") {
            return "Well-developed shoulders create a wider frame and improve upper body aesthetics. They're critical for overhead movements and posture."
        }
        if lower.contains("chest") {
            return "A strong chest provides upper body pressing power and creates a balanced physique. It's essential for pushing movements."
        }
        if lower.contains("back") || lower.contains("lat") {
            return "A strong back creates a V-taper, improves posture, and balances pressing movements. It's foundational for overall strength."
        }
        if lower.contains("arm") || lower.contains("bicep") || lower.contains("tricep") {
            return "Developed arms complete your physique and improve grip strength. Balanced biceps and triceps prevent elbow injuries."
        }
        if lower.contains("leg") || lower.contains("quad") || lower.contains("hamstring") {
            return "Strong legs are the foundation of athleticism. They support every movement and drive overall hormonal response to training."
        }
        if lower.contains("glute") {
            return "Glutes are the largest muscle group and power hip extension. Strong glutes improve performance and prevent lower back pain."
        }
        if lower.contains("core") || lower.contains("ab") {
            return "Core strength stabilizes your entire body during compound movements. It protects your spine and improves force transfer."
        }
        if lower.contains("calf") || lower.contains("calves") {
            return "Calves complete lower body development and improve ankle stability. They're essential for explosive movements."
        }
        return "This area was identified as needing improvement based on your scan. Targeted training will bring up this weak point."
    }

    private func iconForArea(_ area: String) -> String {
        let lower = area.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("shoulder") || lower.contains("delt") { return "figure.boxing" }
        if lower.contains("back") || lower.contains("lat") { return "figure.rowing" }
        if lower.contains("arm") || lower.contains("bicep") || lower.contains("tricep") { return "figure.arms.open" }
        if lower.contains("leg") || lower.contains("quad") || lower.contains("hamstring") { return "figure.run" }
        if lower.contains("glute") { return "figure.stairs" }
        if lower.contains("core") || lower.contains("ab") { return "figure.core.training" }
        if lower.contains("calf") || lower.contains("calves") { return "figure.run" }
        return "figure.mixed.cardio"
    }
}

enum FocusAreaPriority {
    case high
    case moderate
    case maintaining

    var label: String {
        switch self {
        case .high: return "High Priority"
        case .moderate: return "Moderate"
        case .maintaining: return "Maintaining"
        }
    }

    var icon: String {
        switch self {
        case .high: return "flame.fill"
        case .moderate: return "bolt.fill"
        case .maintaining: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .high: return .orange
        case .moderate: return .yellow
        case .maintaining: return .green
        }
    }
}
