import SwiftUI

/// Lets the user fix mistakes in a workout they've just finished. Shows
/// today's logged sets for each exercise in the workout and allows editing
/// weight + reps. Save commits via ExerciseLogService.updateLog.
struct EditFinishedWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let exercises: [Exercise]

    private let logService = ExerciseLogService.shared

    @State private var editedLogs: [ExerciseLog] = []
    @State private var draftStrings: [String: String] = [:]  // setId -> weight string

    private var weightUnit: String { appState.profile.usesMetric ? "kg" : "lbs" }
    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            Group {
                if editedLogs.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(Array(editedLogs.enumerated()), id: \.element.id) { logIndex, log in
                                exerciseCard(logIndex: logIndex, log: log)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("editWorkoutTitle", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save", lang)) { save() }
                        .fontWeight(.semibold)
                        .disabled(editedLogs.isEmpty)
                }
            }
            .onAppear(perform: loadLogs)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing to edit")
                .font(.headline)
            Text("No sets were logged for this workout today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func exerciseCard(logIndex: Int, log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(log.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(log.muscleGroup)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(.capsule)
            }

            VStack(spacing: 8) {
                ForEach(Array(log.sets.enumerated()), id: \.element.id) { setIndex, set in
                    setRow(logIndex: logIndex, setIndex: setIndex, set: set)
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func setRow(logIndex: Int, setIndex: Int, set: SetLog) -> some View {
        HStack(spacing: 10) {
            Text("Set \(setIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            // Weight
            VStack(spacing: 2) {
                Text(weightUnit.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)

                TextField("0", text: weightBinding(setId: set.id, current: set.weight, logIndex: logIndex, setIndex: setIndex))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(width: 60, height: 36)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 8))
            }

            Text("×")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            // Reps
            VStack(spacing: 2) {
                Text("REPS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)

                Stepper(
                    value: Binding(
                        get: { editedLogs[logIndex].sets[setIndex].reps },
                        set: { editedLogs[logIndex].sets[setIndex].reps = max(0, $0) }
                    ),
                    in: 0...50
                ) {
                    Text("\(editedLogs[logIndex].sets[setIndex].reps)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(minWidth: 30)
                }
                .labelsHidden()
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func weightBinding(setId: String, current: Double, logIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { draftStrings[setId] ?? formatWeight(current) },
            set: { val in
                let filtered = val.filter { $0.isNumber || $0 == "." }
                draftStrings[setId] = filtered
                if let parsed = Double(filtered) {
                    editedLogs[logIndex].sets[setIndex].weight = parsed
                } else if filtered.isEmpty {
                    editedLogs[logIndex].sets[setIndex].weight = 0
                }
            }
        )
    }

    private func formatWeight(_ w: Double) -> String {
        guard w > 0 else { return "" }
        return w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }

    private func loadLogs() {
        let names = Set(exercises.map(\.name))
        let calendar = Calendar.current
        let now = Date()
        let todays = logService.loadAll().filter {
            names.contains($0.exerciseName) && calendar.isDate($0.date, inSameDayAs: now)
        }
        // Order by the workout's exercise order so users see them as expected.
        let order = exercises.enumerated().reduce(into: [String: Int]()) { acc, pair in
            acc[pair.element.name] = pair.offset
        }
        editedLogs = todays.sorted { (order[$0.exerciseName] ?? 0) < (order[$1.exerciseName] ?? 0) }
    }

    private func save() {
        for var log in editedLogs {
            log.totalVolume = log.computedVolume
            logService.updateLog(log)
        }
        dismiss()
    }
}
