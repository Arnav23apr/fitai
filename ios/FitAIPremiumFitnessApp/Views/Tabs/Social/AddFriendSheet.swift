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

    /// Trimmed, lowercased search query — single source of truth used by
    /// the UI to decide between helper view / loading / suggestions / no
    /// results.
    private var normalizedQuery: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Mirrors `FriendViewModel.suggestionsMinChars`. Kept inline rather
    /// than exposed on the view model because it's purely a UI gating
    /// concern.
    private let minChars: Int = 3

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

                resultsArea

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

                Spacer(minLength: 0)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
            }
            .onDisappear {
                viewModel.clearSearchSuggestions()
                viewModel.searchResult = nil
                viewModel.searchError = nil
            }
        }
    }

    // MARK: - Results area
    //
    // Below `minChars` we show the helper graphic. Once the user crosses
    // the threshold we either render a loading spinner, the suggestion
    // list, or a "no matches" hint. Errors from the legacy single-result
    // path (e.g. "already friends") render inline too.

    @ViewBuilder
    private var resultsArea: some View {
        if normalizedQuery.count < minChars {
            findYourGymBuddy
                .padding(.top, 28)
        } else if viewModel.isLoadingSuggestions && viewModel.searchSuggestions.isEmpty {
            ProgressView().padding(.top, 28)
        } else if !viewModel.searchSuggestions.isEmpty {
            suggestionsList
        } else if let err = viewModel.searchError {
            Text(err)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 24)
        } else {
            noMatchesView
                .padding(.top, 28)
        }
    }

    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchSuggestions) { profile in
                    SocialProfileRow(profile: profile, trailing: AnyView(addButton(for: profile)))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    Divider()
                        .padding(.leading, 72)
                }
            }
            .padding(.top, 8)
        }
    }

    private func addButton(for profile: SocialProfileSummary) -> some View {
        Button {
            Task {
                await viewModel.sendFriendRequest(toUsername: profile.username)
                // Optimistically remove the row so a successful tap
                // doesn't leave a stale "Add" button behind. If the
                // request actually failed the row will come back on the
                // next keystroke; the toast surfaces the error.
                viewModel.searchSuggestions.removeAll { $0.id == profile.id }
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
        .buttonStyle(.plain)
        .disabled(!hasOwnUsername)
    }

    private var noMatchesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No users match \u{201C}\(normalizedQuery)\u{201D}")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Double-check the spelling or ask them for their exact handle.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by username", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: viewModel.searchText) { _, newValue in
                    // Drive live suggestions. The view model handles
                    // debounce + sub-threshold short-circuit, so calling
                    // this on every keystroke is cheap.
                    viewModel.searchError = nil
                    viewModel.updateSearchSuggestions(newValue)
                }
            if viewModel.isLoadingSuggestions {
                ProgressView()
                    .controlSize(.mini)
                    .padding(.trailing, 2)
            } else if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.searchResult = nil
                    viewModel.searchError = nil
                    viewModel.clearSearchSuggestions()
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
    }
}
