import SwiftUI

struct RatingsCardSheet: View {
    let result: ScanResult
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView {
                ShareCardView(result: result, gender: appState.profile.gender)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("ratings", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("done", lang)) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
