import SwiftUI

/// Lightweight model for a warmup row inside the calculator. Lives
/// outside the sheet so the parent can act on it without leaking the
/// sheet's @State.
struct WarmupSetDraft: Identifiable, Equatable {
    let id = UUID()
    var percent: Double
    var weight: Double
    var reps: Int
}

/// Strong/Hevy-style warmup-set calculator. Takes the working weight,
/// generates 40/60/80% warmup rows (rounded to plate-loadable values),
/// and lets the user nudge percentages and reps before inserting them
/// at the top of the exercise as warmup-tagged sets. Skips the calculator
/// if the working weight is below 60 lbs / 30 kg, since warmups under
/// the empty bar aren't useful.
struct WarmupCalculatorSheet: View {
    let exerciseName: String
    let workingWeight: Double
    let isMetric: Bool
    let weightUnit: String
    let onInsert: ([WarmupSetDraft]) -> Void
    let onCancel: () -> Void

    @State private var workingWeightInput: Double
    @State private var rows: [WarmupSetDraft] = []

    init(
        exerciseName: String,
        workingWeight: Double,
        isMetric: Bool,
        weightUnit: String,
        onInsert: @escaping ([WarmupSetDraft]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exerciseName = exerciseName
        self.workingWeight = workingWeight
        self.isMetric = isMetric
        self.weightUnit = weightUnit
        self.onInsert = onInsert
        self.onCancel = onCancel
        _workingWeightInput = State(initialValue: workingWeight)
    }

    private var minWarmupWeight: Double { isMetric ? 30.0 : 60.0 }

    private var canInsert: Bool {
        workingWeightInput >= minWarmupWeight && !rows.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName)
                        .font(.headline)
                    Text("Generates warmup sets at 40 / 60 / 80% of working weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                workingWeightField

                if workingWeightInput < minWarmupWeight {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("Warmups not generated below \(format(minWarmupWeight)) \(weightUnit). Lifts at this weight don't need a warmup.")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .padding(10)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 10))
                }

                if !rows.isEmpty {
                    VStack(spacing: 8) {
                        ForEach($rows) { $row in
                            warmupRow(row: $row)
                        }
                    }
                }

                Spacer()

                Button {
                    onInsert(rows)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Insert \(rows.count) warmup \(rows.count == 1 ? "set" : "sets")")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canInsert ? Color.orange : Color.orange.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(!canInsert)
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle("Warmup Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear { regenerate() }
            .onChange(of: workingWeightInput) { _, _ in regenerate() }
        }
    }

    private var workingWeightField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Working weight")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", value: $workingWeightInput, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 10))
                Text(weightUnit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func warmupRow(row: Binding<WarmupSetDraft>) -> some View {
        HStack(spacing: 10) {
            Text("\(Int(row.wrappedValue.percent * 100))%")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .frame(width: 50, alignment: .leading)

            Text(format(row.wrappedValue.weight))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            Text(weightUnit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("×")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper(value: row.reps, in: 1...20) {
                Text("\(row.wrappedValue.reps)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func regenerate() {
        guard workingWeightInput >= minWarmupWeight else {
            rows = []
            return
        }
        rows = StrengthMath.warmupSets(workingWeight: workingWeightInput, isMetric: isMetric)
            .map { sample in
                WarmupSetDraft(
                    percent: sample.percent,
                    weight: sample.weight,
                    reps: sample.reps
                )
            }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
