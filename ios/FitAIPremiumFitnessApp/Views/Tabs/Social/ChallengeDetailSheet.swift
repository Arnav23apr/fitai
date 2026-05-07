import SwiftUI
import PhotosUI

/// View a single challenge — accept/decline if pending, submit your photo if
/// active, see the photo battle result if completed. The 1v1 is photo-based:
/// each side submits a physique photo, AI scores it, the higher score wins.
struct ChallengeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: FriendViewModel
    let challenge: PopulatedChallenge

    // Photo submission state
    @State private var selectedPhoto: UIImage? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isSubmitting: Bool = false
    @State private var submitProgress: String = ""
    @State private var errorMessage: String? = nil

    // Share-recap state
    @State private var isRenderingRecap: Bool = false
    @State private var recapShareItem: ShareImage? = nil

    /// Read the latest version of this challenge from the view model so the
    /// sheet updates immediately after Accept/Decline/Submit instead of
    /// showing the stale snapshot it was opened with.
    private var liveChallenge: PopulatedChallenge {
        viewModel.challenges.first(where: { $0.row.id == challenge.row.id }) ?? challenge
    }

    private var defaultBattlePhoto: UIImage? {
        guard let data = appState.loadBattlePhoto() else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    actionsCard
                    if liveChallenge.row.status == "completed" {
                        resultCard
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(categoryLabel(liveChallenge.row.category))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let item = newItem,
                       let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedPhoto = image
                    }
                }
            }
        }
    }

    // MARK: - Header (photo vs photo when both submitted, else placeholders)

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                photoTile(
                    label: "YOU",
                    photoURL: myPhotoURL,
                    score: myScore
                )
                vsBadge
                photoTile(
                    label: liveChallenge.otherUser.username.uppercased(),
                    photoURL: opponentPhotoURL,
                    score: opponentScore
                )
            }
            statusPill
        }
        .padding(20)
        .modifier(GradientCardBackground(
            tintColor: headerTintColor,
            cornerRadius: 16
        ))
    }

    /// Tint colour for the header card — winner glow on completion, neutral blue
    /// during pending/active states.
    private var headerTintColor: Color {
        switch liveChallenge.row.status {
        case "completed":
            let won = liveChallenge.row.winnerUserId == myUserId
            return won ? .yellow : .blue
        default:
            return .blue
        }
    }

    private func photoTile(label: String, photoURL: String?, score: Double?) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
                .tracking(2)
                .lineLimit(1)
            ZStack {
                if let urlStr = photoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure: placeholder
                        @unknown default: placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 110, height: 150)
            .background(Color.primary.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
            Text(score.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.rectangle")
            .font(.system(size: 32))
            .foregroundStyle(.tertiary)
    }

    private var vsBadge: some View {
        Text("VS")
            .font(.headline.weight(.heavy))
            .foregroundStyle(.tertiary)
            .padding(.top, 60)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsCard: some View {
        switch liveChallenge.row.status {
        case "pending":
            if !liveChallenge.iAmChallenger {
                pendingResponderActions
            } else {
                infoCard("Waiting for @\(liveChallenge.otherUser.username) to respond.")
            }
        case "accepted", "in_progress":
            if myPhotoURL == nil {
                photoSubmitCard
            } else {
                infoCard("Your photo's submitted. Waiting for @\(liveChallenge.otherUser.username) to send theirs.")
            }
        case "declined":
            infoCard("Challenge declined.")
        default:
            EmptyView()
        }
    }

    private func infoCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .modifier(GradientCardBackground(tintColor: .blue, cornerRadius: 12))
    }

    private var pendingResponderActions: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.declineChallenge(challenge)
                    dismiss()
                }
            } label: {
                Text("Decline")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 16))
            }
            Button {
                Task {
                    await viewModel.acceptChallenge(challenge)
                    await viewModel.refresh()
                }
            } label: {
                Text("Accept")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.primary)
                    .clipShape(.rect(cornerRadius: 16))
            }
        }
    }

    // MARK: - Photo submit card

    private var photoSubmitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Submit your physique photo")
                .font(.subheadline.weight(.semibold))
            Text("AI judges both photos. Higher score wins. Cannot be changed once submitted.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Preview of the photo about to be submitted
            previewSection

            // Source selectors
            HStack(spacing: 10) {
                if defaultBattlePhoto != nil {
                    Button {
                        selectedPhoto = defaultBattlePhoto
                    } label: {
                        Label("Use default", systemImage: "person.crop.rectangle.stack.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.primary.opacity(0.08))
                            .foregroundStyle(.primary)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Pick", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary.opacity(0.08))
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

            Button {
                Task { await submitPhoto() }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                        Text(submitProgress.isEmpty ? "Submitting…" : submitProgress)
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("Submit photo")
                    }
                }
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedPhoto == nil || isSubmitting ? Color.secondary : Color.primary)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(selectedPhoto == nil || isSubmitting)
        }
        .padding(16)
        .modifier(GradientCardBackground(tintColor: .blue, cornerRadius: 16))
    }

    @ViewBuilder
    private var previewSection: some View {
        if let img = selectedPhoto {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 12))
        } else {
            VStack(spacing: 6) {
                Image(systemName: "person.crop.rectangle.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("Pick a photo to battle with")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    // MARK: - Result

    private var resultCard: some View {
        let won = liveChallenge.row.winnerUserId == myUserId
        return VStack(spacing: 14) {
            Image(systemName: won ? "trophy.fill" : "hand.thumbsup.fill")
                .font(.system(size: 40))
                .foregroundStyle(won ? .yellow : .secondary)
            Text(won ? "You won!" : "Better luck next time.")
                .font(.title2.weight(.bold))
            if won {
                Text("Beat @\(liveChallenge.otherUser.username) — share the win.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await shareRecap() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(isRenderingRecap ? "Rendering…" : "Share recap")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary)
                .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(isRenderingRecap)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .modifier(GradientCardBackground(
            tintColor: won ? .yellow : .red,
            cornerRadius: 16
        ))
        .sheet(item: $recapShareItem) { item in
            BattleRecapShareSheet(activityItems: [item.image])
        }
    }

    /// Render the BattleRecapCardView at full resolution and present the
    /// share sheet. Photos are downloaded from the public URLs first so the
    /// rendered card carries the actual battle visuals, not placeholders.
    private func shareRecap() async {
        guard !isRenderingRecap else { return }
        isRenderingRecap = true
        defer { isRenderingRecap = false }

        let won = liveChallenge.row.winnerUserId == myUserId
        let myImg = await loadImage(from: myPhotoURL)
        let theirImg = await loadImage(from: opponentPhotoURL)

        guard let card = BattleRecapCardView.render(
            myUsername: appState.profile.username.isEmpty ? "you" : appState.profile.username,
            myPhoto: myImg,
            myScore: myScore ?? 0,
            theirUsername: liveChallenge.otherUser.username,
            theirPhoto: theirImg,
            theirScore: opponentScore ?? 0,
            iWon: won
        ) else { return }

        recapShareItem = ShareImage(image: card)
    }

    private func loadImage(from urlStr: String?) async -> UIImage? {
        guard let urlStr, let url = URL(string: urlStr) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    private var statusPill: some View {
        Text(statusLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor)
            .clipShape(.capsule)
    }

    // MARK: - Submit logic

    private func submitPhoto() async {
        guard let img = selectedPhoto else { return }
        guard let userId = appState.currentUserIdPublic else {
            errorMessage = "Not signed in."
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        // 1. Upload photo to Storage
        submitProgress = "Uploading photo…"
        guard let photoURL = await PhotoUploadService.shared.uploadChallengePhoto(
            image: img,
            userId: userId,
            challengeId: liveChallenge.row.id
        ) else {
            errorMessage = "Couldn't upload photo. Try again."
            return
        }

        // 2. Run AI on the photo to get the score
        submitProgress = "AI is judging…"
        let score = await analyzePhotoForScore(img)

        // 3. Submit score + URL to the server
        submitProgress = "Submitting…"
        await viewModel.submitChallengeScore(challenge, score: score, photoURL: photoURL)

        // 4. Save as default battle photo for next time (one-tap reuse)
        if let data = img.jpegData(compressionQuality: 0.85) {
            appState.saveBattlePhoto(data)
        }

        await viewModel.refresh()
    }

    /// Run the existing physique analyzer against the photo and return the
    /// 1-10 overall score. Falls back to 5.0 if AI fails (so the challenge
    /// still resolves rather than stalling).
    private func analyzePhotoForScore(_ image: UIImage) async -> Double {
        guard let base64 = AIService.imageToBase64(image) else { return 5.0 }
        let aiService = AIService()
        let systemPrompt = """
        You are a professional fitness physique analyzer. Analyze the user's \
        physique photo and return an overall score 1-10. Most average gym-goers \
        score 4-6. Only elite physiques score 8+.
        For visibleMuscleGroups, use exactly: "chest", "shoulders", "back", "arms", "legs", "core", "glutes". \
        Set muscleScores to 0 for non-visible groups. \
        For potentialRating, rate 1-10 (be generous, most people score 7+).
        """
        let userPrompt = "Analyze this photo for a 1v1 physique battle. Be precise."
        do {
            let json = try await aiService.analyzeImageWithSchema(
                imageBase64: base64,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
            if let s = json["overallScore"] as? Double { return s }
            if let s = json["overallScore"] as? Int { return Double(s) }
            return 5.0
        } catch {
            return 5.0
        }
    }

    // MARK: - Helpers

    private var myUserId: String? {
        liveChallenge.iAmChallenger ? liveChallenge.row.challengerId : liveChallenge.row.opponentId
    }

    private var myScore: Double? {
        liveChallenge.iAmChallenger ? liveChallenge.row.challengerScore : liveChallenge.row.opponentScore
    }

    private var opponentScore: Double? {
        liveChallenge.iAmChallenger ? liveChallenge.row.opponentScore : liveChallenge.row.challengerScore
    }

    private var myPhotoURL: String? {
        liveChallenge.iAmChallenger ? liveChallenge.row.challengerPhotoURL : liveChallenge.row.opponentPhotoURL
    }

    private var opponentPhotoURL: String? {
        liveChallenge.iAmChallenger ? liveChallenge.row.opponentPhotoURL : liveChallenge.row.challengerPhotoURL
    }

    private var statusLabel: String {
        switch liveChallenge.row.status {
        case "pending":     return "PENDING"
        case "accepted":    return "ACCEPTED"
        case "in_progress": return "IN PROGRESS"
        case "completed":   return "COMPLETED"
        case "declined":    return "DECLINED"
        case "expired":     return "EXPIRED"
        default:            return liveChallenge.row.status.uppercased()
        }
    }

    private var statusColor: Color {
        switch liveChallenge.row.status {
        case "pending", "accepted", "in_progress": return .blue
        case "completed": return .green
        case "declined", "expired": return .gray
        default: return .gray
        }
    }

    private func categoryLabel(_ id: String) -> String {
        switch id {
        case "physique": return "Physique Battle"
        case "workout_volume": return "Volume Battle"
        case "scan_score": return "Scan Score Battle"
        case "streak": return "Streak Battle"
        default: return "1v1 Challenge"
        }
    }
}

/// Wrapper so SwiftUI's `.sheet(item:)` can present the rendered recap
/// (UIImage isn't Identifiable on its own).
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// UIActivityViewController bridge — same pattern as ScanView's local
/// version, but reusable from the social folder.
struct BattleRecapShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

