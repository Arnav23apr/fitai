import SwiftUI

/// Pick an exercise to add to a routine. Searches the full bundled
/// `ExerciseDatabase` (873+ entries from yuhonas/free-exercise-db) plus
/// any user-created custom exercises persisted via `CustomExerciseService`.
/// Muscle filter chips along the top narrow the list to a single group.
struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (PickedExercise) -> Void

    @State private var query: String = ""
    @State private var selectedMuscle: String = ""
    @State private var showCustomCreator: Bool = false
    @State private var customService = CustomExerciseService.shared

    private let muscleFilters: [String] = [
        "All", "Chest", "Back", "Shoulders", "Biceps", "Triceps",
        "Legs", "Glutes", "Abdominals", "Calves", "Forearms", "Cardio",
    ]

    private var visibleExercises: [PickedExercise] {
        let db = ExerciseDatabase.shared

        // Start from either a muscle-filtered list or the full set.
        let base: [String]
        if selectedMuscle.isEmpty || selectedMuscle == "All" {
            base = db.allNames
        } else if selectedMuscle.lowercased() == "legs" {
            // "Legs" is a virtual bucket — combine quad/ham related entries.
            let combined = Set(db.names(forMuscle: "quadriceps"))
                .union(db.names(forMuscle: "hamstrings"))
                .union(db.names(forMuscle: "calves"))
                .union(db.names(forMuscle: "glutes"))
            base = Array(combined).sorted()
        } else {
            base = db.names(forMuscle: selectedMuscle)
        }

        // Apply search query.
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered: [String] = q.isEmpty ? base : base.filter { $0.lowercased().contains(q) }

        // Convert to PickedExercise — pull primary muscle from db.
        var picks = filtered.map { name -> PickedExercise in
            let muscles = db.info(for: name).primaryMuscles
            let group = muscles.first ?? ""
            return PickedExercise(name: name, muscleGroup: group)
        }

        // Add custom exercises that match the search query (regardless of
        // muscle filter — custom always shows so users can find them fast).
        let customMatches = customService.exercises
            .filter { q.isEmpty || $0.name.lowercased().contains(q) }
            .map { PickedExercise(name: $0.name, muscleGroup: $0.primaryMuscle) }

        // Custom on top so user-created moves are easy to spot.
        return customMatches + picks
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                muscleChips
                    .padding(.vertical, 10)

                List {
                    Section {
                        Button {
                            showCustomCreator = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add custom exercise")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Not in the library? Create one — saves to your account.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    let exercises = visibleExercises
                    Section(exercises.isEmpty ? "No matches" : "\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")") {
                        ForEach(exercises) { ex in
                            Button {
                                onPick(ex)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if !ex.muscleGroup.isEmpty {
                                            Text(ex.muscleGroup)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if customService.info(forName: ex.name) != nil {
                                        Text("Custom")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(.capsule)
                                    }
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 17))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustomCreator) {
                CustomExerciseCreatorSheet { custom in
                    // Persist for re-use across routines.
                    customService.add(CustomExercise(
                        name: custom.name,
                        primaryMuscle: custom.muscleGroup
                    ))
                    onPick(custom)
                    dismiss()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var muscleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(muscleFilters, id: \.self) { m in
                    let isSelected = (selectedMuscle.isEmpty && m == "All") || selectedMuscle == m
                    Button {
                        selectedMuscle = (m == "All") ? "" : m
                    } label: {
                        Text(m)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.primary : Color.primary.opacity(0.07))
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: selectedMuscle)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct PickedExercise: Identifiable, Sendable, Hashable {
    var id: String { name }
    let name: String
    let muscleGroup: String
}

private struct CustomExerciseCreatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (PickedExercise) -> Void

    @State private var name: String = ""
    @State private var muscleGroup: String = "Chest"

    private let muscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps",
                                  "Quads", "Hamstrings", "Glutes", "Calves", "Core",
                                  "Cardio", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Standing Cable Row", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Muscle group") {
                    Picker("Muscle group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("Custom exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(PickedExercise(name: trimmed, muscleGroup: muscleGroup))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
