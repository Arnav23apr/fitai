import SwiftUI

struct CoachView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = CoachViewModel()
    @FocusState private var isInputFocused: Bool

    private var lang: String { appState.profile.selectedLanguage }

    private var quickQuestions: [(key: String, fallback: String)] {
        [
            ("whatEatPostWorkout", "What should I eat post-workout?"),
            ("howImproveBench", "How do I improve my bench press?"),
            ("bestWayLoseFat", "Best way to lose fat and build muscle?"),
            ("howMuchProtein", "How much protein do I need daily?"),
            ("createMealPlan", "Create a meal plan for muscle gain"),
            ("howFixShoulders", "How to fix rounded shoulders?"),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    messagesArea
                        .padding(.bottom, 60)

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
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
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.clearChat()
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    if viewModel.messages.isEmpty {
                        welcomeSection
                    }

                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        let showTail = isLastInGroup(index: index)
                        messageBubble(message, showTail: showTail)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if viewModel.isLoading {
                        typingIndicator
                            .id("typing")
                            .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
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
            }
            .onChange(of: viewModel.isLoading) { _, newValue in
                if newValue {
                    withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                        proxy.scrollTo("typing", anchor: .bottom)
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

    private var welcomeSection: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: .blue.opacity(0.3), radius: 16, y: 6)

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text(L.t("yourAICoach", lang))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(L.t("askAnythingFitness", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("tryAsking", lang))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.leading, 6)
                    .padding(.bottom, 2)

                ForEach(quickQuestions, id: \.key) { q in
                    Button(action: {
                        viewModel.sendQuickQuestion(L.t(q.key, lang), profile: appState.profile)
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.blue)
                            Text(L.t(q.key, lang))
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.messages.count)
                }
            }
            .padding(.horizontal, 6)

            Spacer().frame(height: 20)
        }
    }

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
                        MarkdownText(text: message.content)
                            .foregroundStyle(.primary)
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
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 8)
                        .padding(.top, 1)
                }
            }
            .textSelection(.enabled)

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

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 6) {
            coachAvatar

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(delay: Double(index) * 0.15)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(ChatBubbleShape(isUser: false, showTail: true))

            Spacer()
        }
        .padding(.top, 8)
    }

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

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField(L.t("askYourCoach", lang), text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(.capsule)

                Button(action: {
                    viewModel.sendMessage(profile: appState.profile)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            .white,
                            canSend ? Color.blue : Color(.systemGray4)
                        )
                        .scaleEffect(canSend ? 1.0 : 0.9)
                        .animation(.spring(duration: 0.2), value: canSend)
                }
                .disabled(!canSend)
                .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.messages.count)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(
            .ultraThinMaterial
                .shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -4))
        )
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
}

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
            if isUser {
                return Path(roundedRect: rect, cornerRadii: .init(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: radius
                ))
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
}

struct TypingDot: View {
    let delay: Double
    @State private var isAnimating: Bool = false

    var body: some View {
        Circle()
            .fill(.secondary.opacity(0.6))
            .frame(width: 7, height: 7)
            .offset(y: isAnimating ? -4 : 2)
            .animation(
                .easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
