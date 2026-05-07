import SwiftUI

/// Two-tab sheet for friend requests. Incoming = others who want to be your
/// friend (Accept/Decline). Outgoing = requests you've sent (Cancel).
struct FriendRequestsInboxSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel

    @State private var tab: Int = 0

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $tab) {
                    Text("Incoming (\(viewModel.incomingRequests.count))").tag(0)
                    Text("Sent (\(viewModel.outgoingRequests.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Group {
                    if tab == 0 {
                        if viewModel.incomingRequests.isEmpty {
                            emptyState(
                                icon: "tray",
                                title: "No incoming requests",
                                subtitle: "When someone sends you a friend request, it'll show up here."
                            )
                        } else {
                            List {
                                ForEach(viewModel.incomingRequests) { req in
                                    SocialProfileRow(profile: req.otherUser, trailing: AnyView(
                                        HStack(spacing: 8) {
                                            Button {
                                                Task { await viewModel.declineRequest(req) }
                                            } label: {
                                                Text("Decline")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.primary.opacity(0.06))
                                                    .clipShape(.capsule)
                                            }
                                            Button {
                                                Task { await viewModel.acceptRequest(req) }
                                            } label: {
                                                Text("Accept")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(Color(.systemBackground))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color.primary)
                                                    .clipShape(.capsule)
                                            }
                                        }
                                    ))
                                }
                            }
                            .listStyle(.plain)
                            .refreshable {
                                await viewModel.refresh()
                            }
                        }
                    } else {
                        if viewModel.outgoingRequests.isEmpty {
                            emptyState(
                                icon: "paperplane",
                                title: "No pending sent requests",
                                subtitle: "Add a friend by username and your outgoing requests will appear here."
                            )
                        } else {
                            List {
                                ForEach(viewModel.outgoingRequests) { req in
                                    SocialProfileRow(profile: req.otherUser, trailing: AnyView(
                                        Button {
                                            Task { await viewModel.cancelOutgoingRequest(req) }
                                        } label: {
                                            Text("Cancel")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.red)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.10))
                                                .clipShape(.capsule)
                                        }
                                    ))
                                }
                            }
                            .listStyle(.plain)
                            .refreshable {
                                await viewModel.refresh()
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.t("requestsBtn", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
