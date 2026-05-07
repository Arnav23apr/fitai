import SwiftUI

/// Blocked users list with unblock action. Required by App Store guidelines
/// for any app that supports user-to-user interaction.
struct BlockListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.blocks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No one blocked")
                            .font(.subheadline.weight(.semibold))
                        Text("Block someone from their profile to add them here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.blocks) { block in
                            SocialProfileRow(profile: block.blockedUser, trailing: AnyView(
                                Button {
                                    Task { await viewModel.unblock(block.blockedUser) }
                                } label: {
                                    Text("Unblock")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.primary.opacity(0.08))
                                        .clipShape(.capsule)
                                }
                            ))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L.t("blockedTitle", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                }
            }
        }
    }
}
