import SwiftUI

/// Pick (or clear) a superset group for one exercise. Strong/Hevy both
/// model supersets as numbered groups (1, 2, 3); exercises that share
/// a number get a colored rail and rest-skip behavior. The picker
/// surfaces existing groups plus the next available number, plus a
/// "Solo" option to remove the exercise from any superset.
struct SupersetPickerSheet: View {
    let exerciseName: String
    let currentGroup: Int?
    let availableGroups: [Int]
    let onPick: (Int?) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onPick(nil)
                    } label: {
                        HStack {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.secondary)
                            Text("Solo (no superset)")
                                .foregroundStyle(.primary)
                            Spacer()
                            if currentGroup == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Superset group") {
                    ForEach(availableGroups, id: \.self) { group in
                        Button {
                            onPick(group)
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(color(for: group))
                                Text("Group \(group)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if group == currentGroup {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Text("Exercises sharing a group are performed back-to-back. Rest fires only after the last exercise in the round.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    /// Color rotation matches `ActiveSessionView.supersetColor(for:)`.
    private func color(for group: Int) -> Color {
        let palette: [Color] = [.indigo, .teal, .pink, .orange, .green, .cyan]
        let idx = (group - 1) % palette.count
        return palette[max(0, idx)]
    }
}
