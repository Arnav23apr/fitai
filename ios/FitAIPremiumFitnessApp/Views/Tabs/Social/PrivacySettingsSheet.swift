import SwiftUI

/// Privacy controls for the user's profile — privacy mode + searchability.
/// Mutates `appState.profile.privacyMode` and `allowUsernameSearch`, then
/// saveProfile() syncs to Supabase via SupabaseSyncService.
struct PrivacySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var privacyMode: String = "public"
    @State private var allowUsernameSearch: Bool = true

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Profile visibility", selection: $privacyMode) {
                        Text("Public").tag("public")
                        Text("Friends only").tag("friends_only")
                        Text("Private").tag("private")
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Who can see your activity")
                } footer: {
                    Text(visibilityFooter)
                        .font(.caption)
                }

                Section {
                    Toggle("Discoverable by username", isOn: $allowUsernameSearch)
                } footer: {
                    Text("When off, friends can't find you in username search and can't send you a friend request.")
                        .font(.caption)
                }
            }
            .navigationTitle(L.t("privacy", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save", lang)) {
                        appState.profile.privacyMode = privacyMode
                        appState.profile.allowUsernameSearch = allowUsernameSearch
                        appState.saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                privacyMode = appState.profile.privacyMode
                allowUsernameSearch = appState.profile.allowUsernameSearch
            }
        }
    }

    private var visibilityFooter: String {
        switch privacyMode {
        case "private":
            return "Only your friends can see your scans, workouts, and challenges. You won't appear in any feed or leaderboard."
        case "friends_only":
            return "Your activity is only visible to friends. Strangers can still find you by username and send a request."
        default:
            return "Anyone on FitAI can see your activity. You appear in public leaderboards and feeds."
        }
    }
}
