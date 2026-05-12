import SwiftUI
import PhotosUI

/// Unified 1v1 battle entry point. One feature, two modes:
///
/// - **Solo** — pick your photo + an opponent photo locally. AI judges
///   both, result renders instantly via `BattleResultView`. No server
///   round-trips, no auth required.
/// - **Friend** — pick your photo + a friend from your friends list.
///   Photo uploads to `challenge_photos`, AI analyzes it, then we
///   `send_challenge` + `submit_challenge_score` so the friend gets a
///   notification and the row is fully populated for them when they
///   open it. When the friend submits theirs, the challenge resolves
///   and BOTH sides see the same rich `BattleResultView` (constructed
///   from the per-side analyses persisted via migration 021).
///
/// `init(preselectedFriend:)` lets `FriendProfileSheet` deep-link
/// straight into Friend mode with that friend chosen.
struct BattleSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = BattleViewModel()
    @State private var friendViewModel = FriendViewModel()
    @State private var showDefaultSaved: Bool = false
    @State private var showFriendPicker: Bool = false

    /// Mode toggle. Solo = local AI vs picked photo. Friend = server-
    /// backed challenge sent to a selected friend.
    @State private var mode: BattleMode = .solo

    /// Friend selected in Friend mode. Nil = "Pick a friend" placeholder.
    @State private var selectedFriend: SocialProfileSummary? = nil

    /// In-flight + finished states for the Friend send flow.
    @State private var isSendingChallenge: Bool = false
    @State private var sendProgress: String = ""
    @State private var sendSuccess: Bool = false

    /// Preselected friend for deep-link from FriendProfileSheet. When
    /// non-nil, the view boots into Friend mode with this friend chosen.
    let preselectedFriend: SocialProfileSummary?

    init(preselectedFriend: SocialProfileSummary? = nil) {
        self.preselectedFriend = preselectedFriend
    }

    enum BattleMode: String, CaseIterable, Identifiable {
        case solo, friend
        var id: String { rawValue }
        var label: String {
            switch self {
            case .solo: return "Solo"
            case .friend: return "Friend"
            }
        }
    }

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection

                    modePicker

                    HStack(alignment: .top, spacing: 16) {
                        playerPhotoCard

                        vsLabel

                        opponentColumn
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("physiqueBattle", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                primaryActionButton
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(.regularMaterial)
            }
            .sheet(isPresented: $showFriendPicker) { friendPickerSheet }
            .task {
                friendViewModel.attach(appState)
                await friendViewModel.refresh()
                if let preselected = preselectedFriend {
                    mode = .friend
                    selectedFriend = preselected
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.isAnalyzing },
                set: { _ in /* dismissal is driven by the view model */ }
            )) {
                AnalyzingOverlayView(mode: .battle)
                    .interactiveDismissDisabled()
                    .presentationBackground(.black)
            }
            .onAppear {
                viewModel.prefillPlayerPhoto(
                    battlePhotoData: appState.loadBattlePhoto(),
                    profileData: appState.profile.customPhotoData,
                    name: appState.profile.name
                )
                // Reuse the player's most recent scan analysis if it's fresh
                // (within 7 days). Cuts battle AI cost in half by skipping
                // re-analysis of the player's photo, and the scan data is
                // strictly more authoritative than re-analyzing a battle photo.
                if let recent = appState.scanHistory.first {
                    let isFresh = Date().timeIntervalSince(recent.date) < 7 * 24 * 3600
                    if isFresh {
                        viewModel.cachedPlayerAnalysis = AnalysisResult(
                            overallScore: recent.overallScore,
                            muscleScores: MuscleScores(
                                chest: recent.muscleScores.chest,
                                shoulders: recent.muscleScores.shoulders,
                                back: recent.muscleScores.back,
                                arms: recent.muscleScores.arms,
                                legs: recent.muscleScores.legs,
                                core: recent.muscleScores.core,
                                glutes: recent.muscleScores.glutes ?? 0
                            ),
                            potentialRating: recent.potentialRating,
                            visibleMuscleGroups: recent.strongPoints + recent.weakPoints,
                            strongPoints: recent.strongPoints,
                            weakPoints: recent.weakPoints
                        )
                    }
                }
            }
            .onChange(of: viewModel.playerPickerItem) { _, _ in
                Task {
                    await viewModel.loadPlayerPhoto()
                    viewModel.playerPhotoIsDefault = false
                }
            }
            .onChange(of: viewModel.opponentPickerItem) { _, _ in
                Task { await viewModel.loadOpponentPhoto() }
            }
            .fullScreenCover(isPresented: $viewModel.showResult) {
                if let battle = viewModel.battleResult {
                    BattleResultView(battle: battle) {
                        viewModel.reset()
                        dismiss()
                    }
                }
            }
            .alert("Challenge sent", isPresented: $sendSuccess) {
                Button("OK") { dismiss() }
            } message: {
                if let friend = selectedFriend {
                    Text("@\(friend.username) will get a notification. Both sides resolve to the same battle result when they submit.")
                } else {
                    Text("Both sides resolve to the same battle result when they submit.")
                }
            }
        }
    }

    // MARK: - Mode picker

    /// Segmented control switching between solo and friend mode. Hidden
    /// when a friend was preselected via deep-link (the user came from
    /// a friend's profile — mode is implicit).
    @ViewBuilder
    private var modePicker: some View {
        if preselectedFriend == nil {
            Picker("Mode", selection: $mode) {
                ForEach(BattleMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L.t("cancel", lang)) { dismiss() }
                .foregroundStyle(.secondary)
        }
    }

    private var friendPickerSheet: some View {
        FriendBattlePickerSheet(
            friendVM: friendViewModel,
            onPick: { friend in
                if mode == .friend {
                    selectedFriend = friend
                } else {
                    // Solo mode: just borrow the friend's display name
                    // for the opponent label.
                    viewModel.opponentName = friend.displayName
                }
                showFriendPicker = false
            }
        )
        .presentationDetents([.medium, .large])
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.red.opacity(0.3), .red.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
            }

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .solo:
            return L.t("physiqueBattleDesc", lang)
        case .friend:
            return "Challenge a friend to a real 1v1. Both AI-judged."
        }
    }

    // MARK: - Player photo column

    private var playerPhotoCard: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $viewModel.playerPickerItem, matching: .images) {
                if let img = viewModel.playerPhoto {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 190)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(alignment: .topTrailing) {
                            if viewModel.playerPhotoIsDefault {
                                Text(L.t("defaultBadge", lang))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.85))
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text(L.t("addPhoto", lang))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                }
            }

            Text(L.t("youLabel", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if viewModel.playerPhoto != nil {
                Button {
                    if viewModel.playerPhotoIsDefault {
                        appState.clearBattlePhoto()
                        viewModel.playerPhotoIsDefault = false
                    } else if let photo = viewModel.playerPhoto,
                              let data = photo.jpegData(compressionQuality: 0.85) {
                        appState.saveBattlePhoto(data)
                        viewModel.playerPhotoIsDefault = true
                        showDefaultSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showDefaultSaved = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.playerPhotoIsDefault ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text(viewModel.playerPhotoIsDefault ? L.t("removeDefault", lang) : L.t("setAsDefault", lang))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.playerPhotoIsDefault ? .red : .secondary)
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25), value: viewModel.playerPhotoIsDefault)
    }

    // MARK: - Opponent column (mode-dependent)

    /// Solo: photo picker + name textfield. Friend: friend selector
    /// card showing avatar + handle. Tap either placeholder to pick.
    @ViewBuilder
    private var opponentColumn: some View {
        switch mode {
        case .solo:
            soloOpponentColumn
        case .friend:
            friendOpponentColumn
        }
    }

    private var soloOpponentColumn: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $viewModel.opponentPickerItem, matching: .images) {
                if let img = viewModel.opponentPhoto {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 190)
                        .clipShape(.rect(cornerRadius: 16))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text(L.t("addPhoto", lang))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                }
            }

            TextField(
                "",
                text: $viewModel.opponentName,
                prompt: Text(L.t("enterName", lang)).foregroundStyle(.tertiary)
            )
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(width: 140)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var friendOpponentColumn: some View {
        VStack(spacing: 10) {
            Button {
                showFriendPicker = true
            } label: {
                if let friend = selectedFriend {
                    friendTile(friend)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Pick a friend")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                }
            }
            .buttonStyle(.plain)

            Text(selectedFriend.map { "@\($0.username)" } ?? "Pick to challenge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 140)
        }
    }

    private func friendTile(_ friend: SocialProfileSummary) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Profile photo if available, else placeholder gradient.
            if let urlStr = friend.profilePhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholderAvatar(friend: friend)
                    }
                }
                .frame(width: 140, height: 190)
                .clipShape(.rect(cornerRadius: 16))
            } else {
                placeholderAvatar(friend: friend)
                    .frame(width: 140, height: 190)
                    .clipShape(.rect(cornerRadius: 16))
            }

            // Bottom-leading handle pill.
            Text("@\(friend.username)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(8)
        }
    }

    private func placeholderAvatar(friend: SocialProfileSummary) -> some View {
        LinearGradient(
            colors: [.indigo.opacity(0.4), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: friend.avatarSystemName ?? "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.8))
        )
    }

    private var vsLabel: some View {
        Text("VS")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(.red)
            .frame(height: 190)
    }

    // MARK: - Primary action (mode-aware)

    /// Solo → "Start Battle". Friend → "Send Challenge". Both share the
    /// same red gradient + spinner-on-busy treatment so the UI reads
    /// consistently across modes.
    private var primaryActionButton: some View {
        Button {
            switch mode {
            case .solo:
                Task { await viewModel.startBattle(profile: appState.profile) }
            case .friend:
                Task { await sendFriendChallenge() }
            }
        } label: {
            Group {
                if viewModel.isAnalyzing || isSendingChallenge {
                    HStack(spacing: 10) {
                        ProgressView().tint(.primary)
                        Text(primaryActionProgress)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: mode == .solo ? "bolt.fill" : "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(primaryActionLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(canFirePrimaryAction ? .primary : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .modifier(LiquidGlassButton(tint: canFirePrimaryAction ? .red : .gray))
            .opacity(canFirePrimaryAction || viewModel.isAnalyzing || isSendingChallenge ? 1.0 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(!canFirePrimaryAction || viewModel.isAnalyzing || isSendingChallenge)
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.showResult)
        .animation(.snappy(duration: 0.25), value: canFirePrimaryAction)
    }

    private var primaryActionLabel: String {
        switch mode {
        case .solo:  return L.t("startBattle", lang)
        case .friend: return "Send Challenge"
        }
    }

    private var primaryActionProgress: String {
        switch mode {
        case .solo:  return viewModel.analyzeProgress
        case .friend: return sendProgress.isEmpty ? "Sending…" : sendProgress
        }
    }

    private var canFirePrimaryAction: Bool {
        switch mode {
        case .solo:
            return viewModel.canStartBattle
        case .friend:
            return viewModel.playerPhoto != nil && selectedFriend != nil
        }
    }

    // MARK: - Friend-mode send flow

    /// Upload photo → analyze with AI → send challenge → submit our
    /// score+analysis to the new challenge. End state: friend gets a
    /// notification, the challenge row has our side fully populated,
    /// and we show "Challenge sent" and dismiss.
    @MainActor
    private func sendFriendChallenge() async {
        guard let img = viewModel.playerPhoto, let friend = selectedFriend else { return }
        guard let myUserId = appState.currentUserIdPublic else {
            viewModel.errorMessage = "Not signed in."
            return
        }
        guard appState.profile.canCreateChallenge else {
            viewModel.errorMessage = "Upgrade to send challenges."
            return
        }

        isSendingChallenge = true
        defer { isSendingChallenge = false }
        viewModel.errorMessage = nil

        // 1. Send the challenge to get a challenge_id we can attach the
        //    upload+score to. Done first so the bucket folder name is
        //    known before we upload (path is {userId}/{challengeId}.jpg).
        sendProgress = "Sending challenge…"
        let sendResult = await SocialService.shared.sendChallenge(
            opponentUsername: friend.username,
            category: "physique"
        )
        guard case let .success(json) = sendResult,
              let challengeId = json["challenge_id"] as? String else {
            viewModel.errorMessage = "Couldn't create challenge. \(sendResult.failureReason ?? "")"
            return
        }

        // 2. Upload our photo into the bucket.
        sendProgress = "Uploading photo…"
        guard let photoURL = await PhotoUploadService.shared.uploadChallengePhoto(
            image: img,
            userId: myUserId,
            challengeId: challengeId
        ) else {
            viewModel.errorMessage = "Couldn't upload photo. Try again."
            return
        }

        // 3. Analyze the photo (full breakdown for storage + result reuse).
        sendProgress = "AI is judging…"
        let analysis = await analyzePhotoForBattle(img)
        let score = analysis?.overallScore ?? 5.0

        // 4. Submit our score + analysis. The opponent will get a
        //    notification, open ChallengeDetailSheet, and submit theirs.
        //    When both sides exist, the row flips to completed and the
        //    second submitter writes the verdict.
        sendProgress = "Submitting…"
        await friendViewModel.submitChallengeScore(
            PopulatedChallenge(
                row: stubChallengeRow(
                    id: challengeId,
                    challengerId: myUserId,
                    opponentId: friend.id,
                    photoURL: photoURL
                ),
                otherUser: friend,
                iAmChallenger: true
            ),
            score: score,
            photoURL: photoURL,
            analysis: analysis
        )

        // 5. Save as default battle photo for one-tap reuse next time.
        if let data = img.jpegData(compressionQuality: 0.85) {
            appState.saveBattlePhoto(data)
        }

        sendSuccess = true
    }

    /// Run the physique analyzer against `image` and return a
    /// `ChallengeAnalysis`. Mirrors the prompt + parsing used in
    /// `ChallengeDetailSheet.analyzePhotoForResult` so both flows
    /// produce identically-shaped data.
    private func analyzePhotoForBattle(_ image: UIImage) async -> ChallengeAnalysis? {
        guard let base64 = AIService.imageToBase64(image) else { return nil }
        let aiService = AIService()
        let systemPrompt = """
        You are a professional fitness physique analyzer. Analyze the user's \
        physique photo and return an overall score 1-10. Most average gym-goers \
        score 4-6. Only elite physiques score 8+.
        For visibleMuscleGroups, use exactly: "chest", "shoulders", "back", "arms", "legs", "core", "glutes". \
        Set muscleScores to 0 for non-visible groups. \
        For potentialRating, rate 1-10 (be generous, most people score 7+). \
        Also return strongPoints and weakPoints as short arrays of muscle group names.
        """
        let userPrompt = "Analyze this photo for a 1v1 physique battle. Be precise."
        do {
            let json = try await aiService.analyzeImageWithSchema(
                imageBase64: base64,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
            return parseChallengeAnalysis(json)
        } catch {
            return nil
        }
    }

    private func parseChallengeAnalysis(_ json: [String: Any]) -> ChallengeAnalysis {
        func parseDouble(_ v: Any?) -> Double {
            if let d = v as? Double { return d }
            if let i = v as? Int { return Double(i) }
            return 0
        }
        let overall: Double = {
            if let s = json["overallScore"] as? Double { return s }
            if let s = json["overallScore"] as? Int { return Double(s) }
            return 5.0
        }()
        let potential: Double = {
            if let p = json["potentialRating"] as? Double { return p }
            if let p = json["potentialRating"] as? Int { return Double(p) }
            return 8.0
        }()
        let ms = json["muscleScores"] as? [String: Any] ?? [:]
        let scores = CodableMuscleScores(
            from: MuscleScores(
                chest: parseDouble(ms["chest"]),
                shoulders: parseDouble(ms["shoulders"]),
                back: parseDouble(ms["back"]),
                arms: parseDouble(ms["arms"]),
                legs: parseDouble(ms["legs"]),
                core: parseDouble(ms["core"]),
                glutes: parseDouble(ms["glutes"])
            )
        )
        return ChallengeAnalysis(
            overallScore: overall,
            muscleScores: scores,
            potentialRating: potential,
            visibleMuscleGroups: (json["visibleMuscleGroups"] as? [String]) ?? [],
            strongPoints: (json["strongPoints"] as? [String]) ?? [],
            weakPoints: (json["weakPoints"] as? [String]) ?? []
        )
    }

    /// Build a minimal stub `ChallengeRow` for the freshly-sent challenge
    /// so we can pass it through `viewModel.submitChallengeScore` without
    /// needing to re-fetch the row from Supabase between RPC calls.
    /// `submitChallengeScore` only reads the `.row.id` and `iAmChallenger`
    /// for purposes of the activity-feed post-completion path; nullable
    /// fields are fine.
    private func stubChallengeRow(
        id: String,
        challengerId: String,
        opponentId: String,
        photoURL: String
    ) -> ChallengeRow {
        // Decode-only init since ChallengeRow is purely `Decodable`.
        // Going through JSON keeps the codable contract honest.
        let dict: [String: Any] = [
            "id": id,
            "challenger_id": challengerId,
            "opponent_id": opponentId,
            "status": "in_progress",
            "category": "physique",
            "challenger_score": NSNull(),
            "opponent_score": NSNull(),
            "challenger_photo_url": photoURL,
            "opponent_photo_url": NSNull(),
            "winner_user_id": NSNull(),
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "responded_at": NSNull(),
            "completed_at": NSNull(),
            "challenger_analysis": NSNull(),
            "opponent_analysis": NSNull(),
            "verdict": NSNull(),
        ]
        let data = try? JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data, let row = try? decoder.decode(ChallengeRow.self, from: data) {
            return row
        }
        // Should never happen; fall back to a degenerate row that still
        // satisfies the type system. submitChallengeScore tolerates this.
        return decodeFallback()
    }

    private func decodeFallback() -> ChallengeRow {
        let json = "{\"id\":\"00000000-0000-0000-0000-000000000000\",\"challenger_id\":\"\",\"opponent_id\":\"\",\"status\":\"in_progress\",\"category\":\"physique\",\"created_at\":\"2020-01-01T00:00:00Z\"}"
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ChallengeRow.self, from: data))
            ?? (try! decoder.decode(ChallengeRow.self, from: data))
    }
}
