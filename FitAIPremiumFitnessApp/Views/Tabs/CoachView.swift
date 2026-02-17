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
            VStack(spacing: 0) {
                messagesArea

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                inputBar
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("aiCoach", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !viewModel.messages.isEmpty {
                        Button(action: { viewModel.clearChat() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
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
                LazyVStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        welcomeSection
                    }

                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if viewModel.isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text(L.t("yourAICoach", lang))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(L.t("askAnythingFitness", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("tryAsking", lang))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)

                ForEach(quickQuestions, id: \.key) { q in
                    Button(action: {
                        viewModel.sendQuickQuestion(L.t(q.key, lang), profile: appState.profile)
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue.opacity(0.6))
                            Text(L.t(q.key, lang))
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.7))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }

            Spacer().frame(height: 20)
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
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

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.role == .assistant {
                        MarkdownText(text: message.content)
                            .foregroundStyle(.primary)
                    } else {
                        Text(message.content)
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemBackground))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ?
                    AnyShapeStyle(Color(.label)) :
                    AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                )
                .clipShape(
                    .rect(
                        topLeadingRadius: message.role == .user ? 18 : 4,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: message.role == .user ? 4 : 18,
                        topTrailingRadius: 18
                    )
                )
                .textSelection(.enabled)

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 10) {
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

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(delay: Double(index) * 0.2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 18))

            Spacer()
        }
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
        .background(Color.red.opacity(0.1))
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField(L.t("askYourCoach", lang), text: $viewModel.inputText, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        viewModel.sendMessage(profile: appState.profile)
                    }

                Button(action: {
                    viewModel.sendMessage(profile: appState.profile)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            Color.primary.opacity(0.15) : Color.primary
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }
}

struct TypingDot: View {
    let delay: Double
    @State private var isAnimating: Bool = false

    var body: some View {
        Circle()
            .fill(.secondary)
            .frame(width: 6, height: 6)
            .offset(y: isAnimating ? -5 : 3)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
