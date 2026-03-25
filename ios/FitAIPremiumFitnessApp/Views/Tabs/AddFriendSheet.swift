import SwiftUI

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: FriendViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var hapticTrigger: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                if viewModel.isSearching {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Searching...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if let result = viewModel.searchResult {
                    searchResultCard(result)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    Spacer()
                } else if let error = viewModel.searchError {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    howItWorks
                        .padding(.top, 32)
                    Spacer()
                }

                if let msg = viewModel.successMessage {
                    successBanner(msg)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: viewModel.searchResult != nil)
            .animation(.snappy, value: viewModel.successMessage)
            .background(Color(.systemBackground))
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .onAppear { isSearchFocused = true }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("", text: $viewModel.searchText, prompt: Text("Search by username").foregroundStyle(.tertiary))
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onSubmit { viewModel.searchUser() }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchResult = nil
                        viewModel.searchError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))

            Button {
                viewModel.searchUser()
                hapticTrigger += 1
            } label: {
                Text("Search")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(viewModel.searchText.isEmpty ? Color(.systemGray4) : Color.blue)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(viewModel.searchText.isEmpty)
        }
    }

    private func searchResultCard(_ friend: Friend) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Text(friend.avatarEmoji)
                        .font(.system(size: 32))
                }

                VStack(spacing: 4) {
                    Text(friend.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("@\(friend.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    statItem(value: "\(friend.points)", label: "XP", icon: "bolt.fill", color: .yellow)
                    statItem(value: "\(friend.totalWorkouts)", label: "workouts", icon: "figure.strengthtraining.traditional", color: .green)
                    statItem(value: friend.tier, label: "tier", icon: "shield.fill", color: .blue)
                }

                Button {
                    viewModel.sendFriendRequest(to: friend)
                    hapticTrigger += 1
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                        Text("Add Friend")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(20)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var howItWorks: some View {
        VStack(spacing: 20) {
            Text("Find your gym buddy")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 16) {
                instructionRow(icon: "magnifyingglass", color: .blue, text: "Search by their username")
                instructionRow(icon: "person.badge.plus", color: .green, text: "Send a friend request")
                instructionRow(icon: "bolt.fill", color: .red, text: "Challenge them to a 1v1 battle")
            }
            .padding(.horizontal, 20)
        }
    }

    private func instructionRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(14)
        .background(Color.green.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
    }
}
