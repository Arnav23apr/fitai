import SwiftUI

@Observable @MainActor
class CoachViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Typewriter state — word-by-word reveal
    var revealedLength: [UUID: Int] = [:]
    var scrollTrigger: Int = 0
    private var wordBoundaries: [UUID: [Int]] = [:]
    private var revealTasks: [UUID: Task<Void, Never>] = [:]

    private let aiService = AIService()

    /// UserDefaults key for persisting chat history across app launches.
    /// Cleared on logout via `AppState.clearCoachChatHistory()` so it
    /// doesn't bleed between accounts on a shared device.
    private static let historyKey = "coachChatHistory.v1"
    private static let maxStored = 200  // cap so the blob doesn't bloat

    init() {
        loadFromDisk()
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        messages = saved
        // Mark all as fully revealed so they render instantly without
        // re-running the typewriter effect on every cold launch.
        for m in saved where m.role == .assistant {
            revealedLength[m.id] = m.content.count
        }
    }

    private func persistToDisk() {
        let trimmed = messages.suffix(Self.maxStored)
        if let data = try? JSONEncoder().encode(Array(trimmed)) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    static func clearStorage() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    var isRevealing: Bool {
        revealedLength.contains { entry in
            guard let msg = messages.first(where: { $0.id == entry.key }) else { return false }
            return entry.value < msg.content.count
        }
    }

    func revealedText(for message: ChatMessage) -> String {
        guard message.role == .assistant else { return message.content }
        guard let length = revealedLength[message.id] else { return message.content }
        if length >= message.content.count { return message.content }
        let index = message.content.index(message.content.startIndex, offsetBy: min(length, message.content.count))
        return String(message.content[..<index])
    }

    func isMessageRevealing(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant else { return false }
        guard let length = revealedLength[message.id] else { return false }
        return length < message.content.count
    }

    func completeReveal(for message: ChatMessage) {
        revealTasks[message.id]?.cancel()
        revealTasks[message.id] = nil
        revealedLength[message.id] = message.content.count
        wordBoundaries[message.id] = nil
    }

    // MARK: - Word Boundary Computation

    private func computeWordBoundaries(_ text: String) -> [Int] {
        var boundaries: [Int] = []
        var i = text.startIndex

        while i < text.endIndex {
            // Skip whitespace/newlines (include them with the previous word or as leading)
            while i < text.endIndex && (text[i].isWhitespace || text[i].isNewline) {
                i = text.index(after: i)
            }
            guard i < text.endIndex else { break }

            // Consume word characters
            while i < text.endIndex && !text[i].isWhitespace && !text[i].isNewline {
                i = text.index(after: i)
            }

            // Include trailing whitespace with this word
            while i < text.endIndex && text[i] == " " {
                i = text.index(after: i)
            }

            // Include trailing newlines with this word
            while i < text.endIndex && text[i].isNewline {
                i = text.index(after: i)
            }

            boundaries.append(text.distance(from: text.startIndex, to: i))
        }

        return boundaries
    }

    // MARK: - Typewriter Engine

    private func startTypewriter(for message: ChatMessage) {
        let content = message.content
        guard !content.isEmpty else { return }

        let boundaries = computeWordBoundaries(content)
        guard !boundaries.isEmpty else { return }

        wordBoundaries[message.id] = boundaries
        revealedLength[message.id] = 0

        let task = Task { [weak self] in
            var wordIndex = 0
            var previousLength = 0

            while wordIndex < boundaries.count {
                guard !Task.isCancelled else { return }

                // Slow start: 1 word for first 3 words, then 2 words at a time
                let wordsThisTick: Int
                if wordIndex < 3 {
                    wordsThisTick = 1
                } else {
                    wordsThisTick = 2
                }

                wordIndex = min(wordIndex + wordsThisTick, boundaries.count)
                let newLength = boundaries[wordIndex - 1]
                self?.revealedLength[message.id] = newLength

                // Check if we crossed a newline — trigger scroll
                let revealedSlice = String(content.prefix(newLength))
                let previousSlice = String(content.prefix(previousLength))
                let newNewlines = revealedSlice.filter({ $0.isNewline }).count
                let oldNewlines = previousSlice.filter({ $0.isNewline }).count
                if newNewlines > oldNewlines {
                    self?.scrollTrigger += 1
                }
                previousLength = newLength

                // Variable delay for natural rhythm
                var delayNs: UInt64 = 40_000_000 // 40ms base

                if revealedSlice.hasSuffix("\n\n") {
                    delayNs += 200_000_000 // +200ms at paragraph breaks
                } else if revealedSlice.hasSuffix("\n") {
                    // Check if next content starts a bullet or header
                    let remaining = String(content.dropFirst(newLength))
                    if remaining.hasPrefix("- ") || remaining.hasPrefix("* ") {
                        delayNs += 120_000_000 // +120ms before bullets
                    } else if remaining.hasPrefix("#") {
                        delayNs += 150_000_000 // +150ms before headers
                    } else {
                        delayNs += 80_000_000 // +80ms at line breaks
                    }
                } else if revealedSlice.hasSuffix(". ") || revealedSlice.hasSuffix(": ") {
                    delayNs += 60_000_000 // +60ms at sentence ends
                }

                try? await Task.sleep(nanoseconds: delayNs)
            }

            self?.revealTasks[message.id] = nil
            self?.wordBoundaries[message.id] = nil
        }
        revealTasks[message.id] = task
    }

    // MARK: - System Context

    func buildSystemContext(profile: UserProfile) -> String {
        let profileContext = ProfileContextBuilder.buildContext(from: profile)
        return """
        You are Fit AI Coach, a premium personal fitness and nutrition coach inside the Fit AI app.
        Be concise, motivating, and knowledgeable. Use a friendly but professional tone.
        Keep responses focused and actionable — no walls of text.
        Format key points with bullet points when listing things.
        You can help with workout advice, nutrition, form tips, recovery, motivation, and general fitness questions.

        PERSONALIZATION (mandatory, not optional):
        The user profile below is authoritative. Every reply MUST be tailored to it. \
        Reference at least two specific profile fields by name in every response (e.g. their primaryGoal, trainingLocation, weakPoints, holdingBack, currentStreak, latestScore, bodyweight). \
        If they ask a generic question, answer it through the lens of their profile — do not give a textbook answer. \
        If they mention a weak point already in their profile, proactively suggest fixes for it. \
        If they list obstacles in holdingBack, acknowledge them and offer practical workarounds. \
        Do not start replies with "Great question" or any filler — get straight to personalized advice. \
        If your reply could be sent to any random fitness app user without changes, you have failed.

        USER PROFILE:
        \(profileContext)
        \(ProfileContextBuilder.genderEmphasis(for: profile))
        \(ProfileContextBuilder.languageInstruction(for: profile))
        """
    }

    // MARK: - Send Message

    func sendMessage(profile: UserProfile) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        persistToDisk()
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let systemContext = buildSystemContext(profile: profile)
                var apiMessages: [ChatAPIMessage] = [
                    ChatAPIMessage(role: "system", text: systemContext)
                ]
                for msg in messages {
                    apiMessages.append(ChatAPIMessage(role: msg.role.rawValue, text: msg.content))
                }

                let response = try await aiService.chat(messages: apiMessages)
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
                persistToDisk()
                isLoading = false
                startTypewriter(for: assistantMessage)
            } catch {
                #if DEBUG
                print("[CoachViewModel] Error: \(error)")
                #endif
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func sendQuickQuestion(_ question: String, profile: UserProfile) {
        inputText = question
        sendMessage(profile: profile)
    }

    func clearChat() {
        for task in revealTasks.values { task.cancel() }
        revealTasks.removeAll()
        revealedLength.removeAll()
        wordBoundaries.removeAll()
        messages.removeAll()
        errorMessage = nil
        Self.clearStorage()
    }
}
