import SwiftUI

/// Search a username, view their profile, send a real friend request.
/// Replaces the previous AddFriendSheet that used the local Friend type and
/// instantly added friends without a request flow.
struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel

    private var lang: String { appState.profile.selectedLanguage }

    /// True when the signed-in user has set a username. Friend requests are
    /// blocked otherwise — both visually here and server-side in the RPC —
    /// because empty-username senders show up in the recipient's inbox as
    /// "@" with no identity.
    private var hasOwnUsername: Bool {
        !appState.profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasResultOrError: Bool {
        viewModel.searchResult != nil || viewModel.isSearching || viewModel.searchError != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasOwnUsername {
                    usernameRequiredBanner
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let result = viewModel.searchResult {
                    SocialProfileRow(profile: result, trailing: AnyView(
                        Button {
                            Task {
                                await viewModel.sendFriendRequest(toUsername: result.username)
                                viewModel.searchResult = nil
                                viewModel.searchText = ""
                            }
                        } label: {
                            Text(L.t("addBtn", lang))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(hasOwnUsername ? Color(.systemBackground) : Color.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(hasOwnUsername ? Color.primary : Color.primary.opacity(0.20))
                                .clipShape(.capsule)
                        }
                        .disabled(!hasOwnUsername)
                    ))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                } else if viewModel.isSearching {
                    ProgressView().padding(.top, 24)
                } else if let err = viewModel.searchError {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                } else {
                    findYourGymBuddy
                        .padding(.top, 28)
                }

                if let s = viewModel.successMessage {
                    Label(s, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.top, 12)
                }
                if let e = viewModel.lastError {
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 12)
                }

                Spacer()
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
            }
        }
    }

    // MARK: - Empty state

    private var findYourGymBuddy: some View {
        VStack(spacing: 18) {
            Text("Find your gym buddy")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            VStack(spacing: 14) {
                helperRow(
                    icon: "magnifyingglass",
                    tint: Color(red: 0.20, green: 0.55, blue: 1.00),
                    text: "Search by their username"
                )
                helperRow(
                    icon: "person.fill.badge.plus",
                    tint: Color(red: 0.20, green: 0.78, blue: 0.40),
                    text: "Send a friend request"
                )
                helperRow(
                    icon: "bolt.fill",
                    tint: Color(red: 1.00, green: 0.30, blue: 0.30),
                    text: "Challenge them to a 1v1 battle"
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func helperRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private var usernameRequiredBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Set your username first")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Your friends need a handle to recognize you. Update it in Profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by username", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await viewModel.searchUser() }
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchResult = nil
                        viewModel.searchError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.primary.opacity(0.08))
            .clipShape(.rect(cornerRadius: 14))

            Button {
                Task { await viewModel.searchUser() }
            } label: {
                Text("Search")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.primary.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }
}
