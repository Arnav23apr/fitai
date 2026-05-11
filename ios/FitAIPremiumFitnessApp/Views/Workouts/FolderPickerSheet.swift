import SwiftUI

/// "Move to folder" sheet for routines. Lists existing folders, lets
/// the user create a new one inline, and offers a "no folder" option to
/// uncategorize. Mirrors Strong's folder picker (which calls this
/// "Move to Folder") so users coming from there feel at home.
struct FolderPickerSheet: View {
    let currentFolder: String?
    let existingFolders: [String]
    let onPick: (String?) -> Void
    let onCancel: () -> Void

    @State private var newFolderName: String = ""
    @FocusState private var newFolderFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onPick(nil)
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.minus")
                                .foregroundStyle(.secondary)
                            Text("No folder")
                                .foregroundStyle(.primary)
                            Spacer()
                            if currentFolder == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !existingFolders.isEmpty {
                    Section("Folders") {
                        ForEach(existingFolders, id: \.self) { folder in
                            Button {
                                onPick(folder)
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.indigo)
                                    Text(folder)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if folder == currentFolder {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("New folder") {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(.green)
                        TextField("Hypertrophy block 1", text: $newFolderName)
                            .focused($newFolderFocused)
                            .submitLabel(.done)
                            .onSubmit(commitNewFolder)
                        Button("Add", action: commitNewFolder)
                            .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Move to folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onPick(trimmed)
    }
}
