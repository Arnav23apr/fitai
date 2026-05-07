import SwiftUI

/// Build or edit a user routine. Pick exercises from the database, edit
/// sets/reps, set per-exercise rest overrides on top of a routine default.
struct RoutineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initial: Routine?
    let onSave: (Routine?) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var defaultRest: Int
    @State private var exercises: [RoutineExercise]
    @State private var showExercisePicker: Bool = false
    @State private var editingExerciseId: String? = nil

    init(initial: Routine?, onSave: @escaping (Routine?) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _name = State(initialValue: initial?.name ?? "")
        _icon = State(initialValue: initial?.icon ?? "dumbbell.fill")
        _defaultRest = State(initialValue: initial?.defaultRestSeconds ?? 90)
        _exercises = State(initialValue: initial?.exercises ?? [])
    }

    private let iconOptions = ["dumbbell.fill", "figure.strengthtraining.traditional",
                                "figure.run", "figure.core.training", "flame.fill",
                                "heart.fill", "bolt.fill"]

    private let restPresets = [30, 45, 60, 75, 90, 120, 180, 240]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Day", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(iconOptions, id: \.self) { sf in
                                Button {
                                    icon = sf
                                } label: {
                                    Image(systemName: sf)
                                        .font(.system(size: 18))
                                        .foregroundStyle(icon == sf ? Color(.systemBackground) : Color.primary)
                                        .frame(width: 44, height: 44)
                                        .background(icon == sf ? Color.primary : Color.primary.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Default rest") {
                    Picker("Rest between sets", selection: $defaultRest) {
                        ForEach(restPresets, id: \.self) { s in
                            Text(formatRest(s)).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Exercises") {
                    if exercises.isEmpty {
                        Text("No exercises yet. Tap Add below.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($exercises) { $ex in
                            exerciseRow($ex)
                        }
                        .onMove { from, to in
                            exercises.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { idx in
                            exercises.remove(atOffsets: idx)
                        }
                    }
                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(initial == nil ? "New Split" : "Edit Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave(nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let routine = Routine(
                            id: initial?.id ?? UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            icon: icon,
                            exercises: exercises,
                            defaultRestSeconds: defaultRest,
                            createdAt: initial?.createdAt ?? Date(),
                            updatedAt: Date()
                        )
                        onSave(routine)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !exercises.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { picked in
                    exercises.append(RoutineExercise(
                        name: picked.name,
                        muscleGroup: picked.muscleGroup
                    ))
                }
            }
        }
    }

    private func exerciseRow(_ ex: Binding<RoutineExercise>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(ex.wrappedValue.name)
                            .font(.subheadline.weight(.semibold))
                        if let group = ex.wrappedValue.supersetGroup {
                            Text("SS\(group)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(supersetColor(group))
                                .clipShape(.capsule)
                        }
                    }
                    if !ex.wrappedValue.muscleGroup.isEmpty {
                        Text(ex.wrappedValue.muscleGroup)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Stepper(value: ex.sets, in: 1...10) {
                    Text("Sets: \(ex.wrappedValue.sets)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()
                Text("Sets: \(ex.wrappedValue.sets)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Reps")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("8-12", text: ex.reps)
                    .font(.caption.weight(.medium))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 90)
                Spacer()

                // RPE / RIR target — Hevy / Strong style "@8" pill.
                Menu {
                    Button("None") { ex.wrappedValue.targetRPE = nil }
                    ForEach([6, 7, 8, 9, 10], id: \.self) { rpe in
                        Button("RPE \(rpe)") { ex.wrappedValue.targetRPE = rpe }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: 10))
                        Text(ex.wrappedValue.targetRPE.map { "@\($0)" } ?? "RPE")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(ex.wrappedValue.targetRPE != nil ? .primary : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.capsule)
                }

                // Rest override picker.
                Menu {
                    Button("Use default (\(formatRest(defaultRest)))") {
                        ex.wrappedValue.restSecondsOverride = nil
                    }
                    ForEach(restPresets, id: \.self) { s in
                        Button(formatRest(s)) {
                            ex.wrappedValue.restSecondsOverride = s
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text(formatRest(ex.wrappedValue.restSecondsOverride ?? defaultRest))
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.capsule)
                }
            }

            // Superset group picker — small chip menu. Tapping cycles through
            // None → 1 → 2 → 3 → None, which in practice is enough for any
            // training split (PPL doesn't usually exceed 3 supersets).
            HStack(spacing: 8) {
                Menu {
                    Button("Solo (no superset)") { ex.wrappedValue.supersetGroup = nil }
                    ForEach(1...4, id: \.self) { g in
                        Button("Superset \(g)") { ex.wrappedValue.supersetGroup = g }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text(ex.wrappedValue.supersetGroup.map { "Superset \($0)" } ?? "Solo")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(ex.wrappedValue.supersetGroup != nil ? .primary : .tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.capsule)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    /// Pick a stable color per superset group so the user can visually
    /// distinguish multiple supersets in one workout. Cycles 4 colors.
    private func supersetColor(_ group: Int) -> Color {
        switch group % 4 {
        case 1: return .blue
        case 2: return .orange
        case 3: return .purple
        default: return .green
        }
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}
