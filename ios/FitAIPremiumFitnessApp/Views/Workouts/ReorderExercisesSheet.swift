import SwiftUI

/// Drag-to-reorder sheet for exercises inside an active workout. Uses
/// SwiftUI's native List + onMove + EditMode so the rows pick up the
/// system grip handle and the standard iOS reorder feel without any
/// custom gesture wiring. Save commits the new order back to the
/// session; cancel discards.
struct ReorderExercisesSheet: View {
    let exercises: [SessionExercise]
    let onSave: ([SessionExercise]) -> Void
    let onCancel: () -> Void

    @State private var draft: [SessionExercise] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(draft) { ex in
                    HStack(spacing: 12) {
                        Text("\(draft.firstIndex(where: { $0.id == ex.id }).map { $0 + 1 } ?? 0)")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text("\(ex.sets.count) set\(ex.sets.count == 1 ? "" : "s")")
                                if !ex.muscleGroup.isEmpty {
                                    Text("·")
                                    Text(ex.muscleGroup)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    draft.move(fromOffsets: source, toOffset: destination)
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = exercises
            }
        }
    }
}
