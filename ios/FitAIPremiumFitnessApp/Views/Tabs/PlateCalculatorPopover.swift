import SwiftUI

struct PlateCalculatorPopover: View {
    let target: Double
    let unit: PlateCalculator.Unit

    private var bar: Double { PlateCalculator.defaultBar(for: unit) }
    private var result: PlateCalculator.Result {
        PlateCalculator.compute(target: target, bar: bar, unit: unit)
    }
    private var unitLabel: String { unit == .kg ? "kg" : "lb" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("Plate Loading")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatted(target) + " " + unitLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatted(bar)) \(unitLabel)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            .clipShape(.rect(cornerRadius: 10))

            if !result.perSide.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Each side")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    ForEach(Array(PlateCalculator.grouped(result.perSide).enumerated()), id: \.offset) { _, group in
                        HStack(spacing: 10) {
                            plateChip(group.weight)
                            Text("× \(group.count)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Spacer()
                            Text("\(formatted(group.weight * Double(group.count))) \(unitLabel)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            } else if target <= bar {
                Text("Just the bar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            if result.leftover > 0.01 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Can't reach exactly with standard plates — short by \(formatted(result.leftover)) \(unitLabel).")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func plateChip(_ weight: Double) -> some View {
        Text(formatted(weight))
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(plateColor(weight))
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }

    private func plateColor(_ weight: Double) -> Color {
        // Mimic IPF color coding loosely.
        if weight >= 25 || weight >= 45 { return .red }
        if weight >= 20 || weight >= 35 { return .blue }
        if weight >= 15 || weight >= 25 { return .yellow.opacity(0.85) }
        if weight >= 10 { return .green }
        if weight >= 5 { return .gray }
        return Color.gray.opacity(0.6)
    }

    private func formatted(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.2g", w)
    }
}
