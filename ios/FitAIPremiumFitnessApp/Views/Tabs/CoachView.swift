import SwiftUI
import UIKit

struct CoachView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = CoachViewModel()
    @FocusState private var isInputFocused: Bool

    /// Snapshot of an active workout session passed in when Coach is
    /// opened mid-workout. When non-nil, prepended to the user's prompt
    /// so Coach can answer "what did I just do?" / "should I bump weight?"
    /// with real context. nil = standard out-of-session Coach.
    let sessionContext: String?

    init(sessionContext: String? = nil) {
        self.sessionContext = sessionContext
    }

    // Welcome entrance phases
    @State private var welcomePhase: Int = -1
    @State private var showConfirmClear: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showVoiceCapture: Bool = false
    @State private var showCoachPhotoScanner: Bool = false

    // Haptic generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    // Send button animation
    @State private var sendRotation: Double = 0
    @State private var sendScale: Double = 1.0

    private var lang: String { appState.profile.selectedLanguage }

    private struct QuickQuestion {
        let key: String
        let fallback: String
        let icon: String
        let color: Color
    }

    private var quickQuestions: [QuickQuestion] {
        [
            QuickQuestion(key: "whatEatPostWorkout", fallback: "What should I eat post-workout?", icon: "fork.knife", color: .green),
            QuickQuestion(key: "howImproveBench", fallback: "How do I improve my bench press?", icon: "figure.strengthtraining.traditional", color: .blue),
            QuickQuestion(key: "bestWayLoseFat", fallback: "Best way to lose fat and build muscle?", icon: "flame.fill", color: .orange),
            QuickQuestion(key: "howMuchProtein", fallback: "How much protein do I need daily?", icon: "scalemass.fill", color: .purple),
            QuickQuestion(key: "createMealPlan", fallback: "Create a meal plan for muscle gain", icon: "list.clipboard.fill", color: .cyan),
            QuickQuestion(key: "howFixShoulders", fallback: "How to fix rounded shoulders?", icon: "figure.walk", color: .pink),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    messagesArea
                        .padding(.bottom, 60)

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                inputBar
            }
            .navigationTitle(L.t("aiCoach", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !viewModel.messages.isEmpty {
                        Button(action: {
                            notification.prepare()
                            showConfirmClear = true
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallSheet(context: .coach) }
            .confirmationDialog("Clear conversation?", isPresented: $showConfirmClear, titleVisibility: .visible) {
                Button("Clear Chat", role: .destructive) {
                    notification.notificationOccurred(.warning)
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.clearChat()
                    }
                    // Reset welcome phase for re-entrance
                    welcomePhase = -1
                    startWelcomeAnimation()
                }
            }
            .onAppear {
                impactLight.prepare()
                impactMedium.prepare()
                notification.prepare()
                selection.prepare()
                startWelcomeAnimation()
                // Hand off active-session snapshot (if any) so Coach
                // can answer in-workout questions without asking.
                viewModel.sessionContext = sessionContext
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                if newValue != nil {
                    notification.notificationOccurred(.error)
                }
            }
        }
    }

    // MARK: - Welcome Animation

    private func startWelcomeAnimation() {
        guard viewModel.messages.isEmpty else { return }
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s initial delay
            withAnimation(.spring(duration: 0.6, bounce: 0.15)) { welcomePhase = 0 }
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(duration: 0.5, bounce: 0.1)) { welcomePhase = 1 }
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(duration: 0.5, bounce: 0.1)) { welcomePhase = 2 }
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeOut(duration: 0.3)) { welcomePhase = 3 }
            try? await Task.sleep(nanoseconds: 100_000_000)
            // Chips cascade
            for i in 4...9 {
                withAnimation(.spring(duration: 0.4, bounce: 0.12)) { welcomePhase = i }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    if viewModel.messages.isEmpty {
                        welcomeSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        let showTail = isLastInGroup(index: index)
                        messageBubble(message, showTail: showTail)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: message.role == .user
                                    ? .move(edge: .trailing).combined(with: .opacity)
                                    : .offset(y: 8).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if viewModel.isLoading {
                        premiumTypingIndicator
                            .id("typing")
                            .transition(.offset(y: 8).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                    if viewModel.isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                // Haptic when AI response arrives
                if let last = viewModel.messages.last, last.role == .assistant {
                    notification.notificationOccurred(.success)
                }
            }
            .onChange(of: viewModel.isLoading) { _, newValue in
                if newValue {
                    withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.scrollTrigger) { _, _ in
                // Follow scroll during typewriter reveal when new lines appear
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func isLastInGroup(index: Int) -> Bool {
        let messages = viewModel.messages
        if index == messages.count - 1 { return true }
        return messages[index].role != messages[index + 1].role
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 40)

            // Animated AI Icon
            animatedAIIcon
                .scaleEffect(welcomePhase >= 0 ? 1.0 : 0.6)
                .opacity(welcomePhase >= 0 ? 1.0 : 0)

            // Title + Subtitle
            VStack(spacing: 8) {
                Text(L.t("yourAICoach", lang))
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)
                    .offset(y: welcomePhase >= 1 ? 0 : 12)
                    .opacity(welcomePhase >= 1 ? 1.0 : 0)

                Text(L.t("askAnythingFitness", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .offset(y: welcomePhase >= 2 ? 0 : 8)
                    .opacity(welcomePhase >= 2 ? 1.0 : 0)
            }

            // Plan-modification capability banner. Surfaces an underused
            // power-user feature: I can also mutate the user's workout
            // templates (PlanModificationService). Tap dismisses Coach so
            // they return to the Workouts hub where the same callout
            // routes them to PlanModSheet.
            Button {
                impactLight.impactOccurred(intensity: 0.6)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.30), .indigo.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I can edit your workout plan too")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Tap a template's ⋯ → Modify with Coach")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.purple)
                }
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [.purple.opacity(0.07), .indigo.opacity(0.03), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.purple.opacity(0.18), lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
            .opacity(welcomePhase >= 3 ? 1.0 : 0)
            .padding(.horizontal, 6)

            // Quick Questions
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("tryAsking", lang))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.leading, 6)
                    .padding(.bottom, 2)
                    .opacity(welcomePhase >= 3 ? 1.0 : 0)

                ForEach(Array(quickQuestions.enumerated()), id: \.element.key) { index, q in
                    Button(action: {
                        impactLight.impactOccurred(intensity: 0.6)
                        viewModel.sendQuickQuestion(L.t(q.key, lang), profile: appState.profile)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: q.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(q.color)
                                .frame(width: 20)

                            Text(L.t(q.key, lang))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(ChipPressStyle())
                    .scaleEffect(welcomePhase >= (4 + index) ? 1.0 : 0.92)
                    .opacity(welcomePhase >= (4 + index) ? 1.0 : 0)
                }
            }
            .padding(.horizontal, 6)

            Spacer().frame(height: 20)
        }
    }

    // MARK: - Animated AI Icon

    private var animatedAIIcon: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let angle = Angle.degrees(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360)
            let pulsePhase = sin(timeline.date.timeIntervalSinceReferenceDate * 1.5)
            let glowScale = 1.0 + pulsePhase * 0.08

            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(glowScale)

                // Main circle with rotating gradient
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .blue, Color(red: 1, green: 0.45, blue: 0.35), .purple],
                            center: .center,
                            angle: angle
                        )
                    )
                    .frame(width: 72, height: 72)

                // Inner overlay for depth
                Circle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage, showTail: Bool) -> some View {
        let isUser = message.role == .user

        return HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                if showTail {
                    coachAvatar
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                Group {
                    if message.role == .assistant {
                        let text = viewModel.revealedText(for: message)
                        let revealing = viewModel.isMessageRevealing(message)

                        HStack(alignment: .bottom, spacing: 0) {
                            MarkdownText(text: text)
                                .foregroundStyle(.primary)

                            if revealing {
                                TypewriterCursor()
                                    .padding(.leading, 1)
                                    .padding(.bottom, 2)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if revealing {
                                viewModel.completeReveal(for: message)
                                impactLight.impactOccurred(intensity: 0.4)
                            }
                        }
                    } else {
                        Text(message.content)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ?
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ) :
                    AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                )
                .clipShape(ChatBubbleShape(isUser: isUser, showTail: showTail))

                if showTail {
                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 8)
                        .padding(.top, 1)
                }
            }
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                    impactLight.impactOccurred(intensity: 0.6)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.top, showTail && viewModel.messages.first?.id != message.id ? 8 : 0)
    }

    private var coachAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Premium Typing Indicator

    private var premiumTypingIndicator: some View {
        HStack(alignment: .bottom, spacing: 6) {
            coachAvatar

            HStack(spacing: 3) {
                WaveformBars()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(ChatBubbleShape(isUser: false, showTail: true))

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red.opacity(0.8))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button(action: { viewModel.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.red.opacity(0.08))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)

            if !appState.profile.isPremium {
                freeQuotaHint
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Voice + photo entry points are sunset for now; the
                // sheets and handlers below remain wired so we can flip
                // them back on without re-plumbing.

                TextField(L.t("askYourCoach", lang), text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                isInputFocused ? Color.blue.opacity(0.3) : Color.clear,
                                lineWidth: 1.5
                            )
                            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                    )

                Button(action: sendAction) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            .white,
                            canSend ? Color.blue : Color(.systemGray4)
                        )
                        .scaleEffect(sendScale)
                        .rotationEffect(.degrees(sendRotation))
                        .animation(.spring(duration: 0.2), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showVoiceCapture) {
            CoachVoiceCaptureSheet { transcript in
                viewModel.inputText = (viewModel.inputText.isEmpty ? "" : viewModel.inputText + " ") + transcript
            }
            .environment(appState)
        }
        .fullScreenCover(isPresented: $showCoachPhotoScanner) {
            WeightScannerView(
                onCapture: { image in
                    showCoachPhotoScanner = false
                    Task { await analyzeCoachPhoto(image) }
                },
                onCancel: { showCoachPhotoScanner = false }
            )
        }
    }

    @MainActor
    private func analyzeCoachPhoto(_ image: UIImage) async {
        let result = await WeightOCRService.shared.analyze(image: image, profile: appState.profile)
        // Compose a natural-language description for the chat field. The
        // user can refine and send.
        var pieces: [String] = []
        if let exercise = result.exercise { pieces.append(exercise) }
        if let weight = result.weight {
            let w = weight == weight.rounded() ? "\(Int(weight))" : String(format: "%.1f", weight)
            pieces.append("\(w) \(result.unit)")
        }
        if pieces.isEmpty {
            viewModel.inputText = "I just took a photo at the gym. Can you help me figure out what I should log?"
        } else {
            viewModel.inputText = "I'm doing \(pieces.joined(separator: " at "))"
        }
    }

    private var freeQuotaHint: some View {
        let used = appState.profile.aiChatMessagesUsed
        let total = UserProfile.freeAIChatQuota
        let remaining = max(total - used, 0)
        return Button(action: { showPaywall = true }) {
            HStack(spacing: 6) {
                Image(systemName: remaining == 0 ? "lock.fill" : "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(remaining == 0 ? .orange : .secondary)
                Text(remaining == 0
                     ? "Free messages used. Unlock unlimited"
                     : "\(remaining) of \(total) free messages left · Upgrade")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func sendAction() {
        guard appState.profile.canSendAICoachMessage else {
            notification.notificationOccurred(.warning)
            showPaywall = true
            return
        }

        impactMedium.impactOccurred()

        // Button animation
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            sendScale = 0.8
            sendRotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                sendScale = 1.0
            }
        }

        viewModel.sendMessage(profile: appState.profile)

        if !appState.profile.isPremium {
            appState.profile.aiChatMessagesUsed += 1
            appState.saveProfile()
        }
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
}

// MARK: - Chip Press Button Style

private struct ChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Typewriter Cursor

private struct TypewriterCursor: View {
    @State private var visible: Bool = true

    var body: some View {
        Text("|")
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Waveform Bars (Premium Typing Indicator)

private struct WaveformBars: View {
    private let barCount = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = time * 4.0 + Double(i) * 0.8
                    let height = 6.0 + sin(phase) * 6.0

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3, height: height)
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isUser: Bool
    let showTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailRadius: CGFloat = 6

        if showTail {
            if isUser {
                return Path(roundedRect: rect, cornerRadii: .init(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: tailRadius,
                    topTrailing: radius
                ))
            } else {
                return Path(roundedRect: rect, cornerRadii: .init(
                    topLeading: tailRadius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: radius
                ))
            }
        } else {
            return Path(roundedRect: rect, cornerRadii: .init(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            ))
        }
    }
}
