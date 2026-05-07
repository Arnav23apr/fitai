import SwiftUI

/// Report flow with predefined reasons (required for App Store approval on
/// any app with direct user-to-user content).
struct ReportUserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel
    let user: SocialProfileSummary

    private var lang: String { appState.profile.selectedLanguage }

    @State private var selectedReason: String = "harassment"
    @State private var details: String = ""
    @State private var alsoBlock: Bool = true
    @State private var isSubmitting: Bool = false

    private let reasons: [(id: String, label: String)] = [
        ("harassment", "Harassment or bullying"),
        ("inappropriate_photo", "Inappropriate photo"),
        ("fake_account", "Fake or impersonation account"),
        ("spam", "Spam or fraud"),
        ("underage", "Under 13 / impersonating a minor"),
        ("other", "Something else")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SocialProfileRow(profile: user)
                }
                Section("Reason") {
                    ForEach(reasons, id: \.id) { reason in
                        Button {
                            selectedReason = reason.id
                        } label: {
                            HStack {
                                Text(reason.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                Section("Details (optional)") {
                    TextField("Add context", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Toggle("Also block this user", isOn: $alsoBlock)
                } footer: {
                    Text("Blocking removes any friendship and prevents future contact. Reports are reviewed by our team.")
                        .font(.caption)
                }
            }
            .navigationTitle(L.t("reportUser", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .fontWeight(.semibold)
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            await viewModel.report(user, reason: selectedReason, details: details)
            if alsoBlock {
                await viewModel.block(user)
            }
            dismiss()
        }
    }
}
