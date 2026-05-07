import SwiftUI

/// Small bottom-sheet asking the user whether to save the just-finished
/// session as a reusable template. Skip → straight to share screen. Save →
/// persists the routine then transitions to the share screen.
///
/// Strong-style behavior: appears between Finish and the post-workout
/// summary, with a sane default name + folder picker (folders are not
/// shipped yet — single My Templates bucket).
struct SaveAsTemplatePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let defaultName: String
    let onSave: (String) -> Void
    let onSkip: () -> Void

    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)
                Text("Save as Template?")
                    .font(.title3.weight(.bold))
                Text("Reuse this exact workout later from your Templates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 6) {
                Text("Template Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Push Day", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { commitSave() }
            }
            .padding(.horizontal, 18)

            HStack(spacing: 10) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.primary.opacity(0.07))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)

                Button {
                    commitSave()
                } label: {
                    Text("Save")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(canSave ? Color.blue : Color.blue.opacity(0.4))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(Color(.systemBackground))
        .onAppear {
            if name.isEmpty { name = defaultName }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func commitSave() {
        guard canSave else { return }
        onSave(name)
    }
}

/// Glue: turn an `Optional<WorkoutShareCardData>` binding into an
/// `Optional<Identifiable>` binding so it can drive a `.fullScreenCover(item:)`.
/// `WorkoutShareCardData` doesn't need to itself be Identifiable; we wrap.
extension Binding where Value == WorkoutShareCardData? {
    var asIdentifiable: Binding<IdentifiableWorkoutShareData?> {
        Binding<IdentifiableWorkoutShareData?>(
            get: { wrappedValue.map(IdentifiableWorkoutShareData.init) },
            set: { wrappedValue = $0?.value }
        )
    }
}

struct IdentifiableWorkoutShareData: Identifiable {
    let id = UUID()
    let value: WorkoutShareCardData
}
