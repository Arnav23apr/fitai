import SwiftUI

@Observable
class CoachViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let aiService = AIService()

    func buildSystemContext(profile: UserProfile) -> String {
        let profileContext = ProfileContextBuilder.buildContext(from: profile)
        return """
        You are Fit AI Coach, a premium personal fitness and nutrition coach inside the Fit AI app.
        Be concise, motivating, and knowledgeable. Use a friendly but professional tone.
        Keep responses focused and actionable — no walls of text.
        Format key points with bullet points when listing things.
        You can help with workout advice, nutrition, form tips, recovery, motivation, and general fitness questions.
        
        Here is the user's full profile from onboarding and activity:
        \(profileContext)
        
        Always tailor your advice to this user's specific goals, experience level, body stats, challenges, and training preferences.
        If they have weak points, proactively suggest ways to improve them.
        If they have challenges/obstacles, be empathetic and offer practical solutions.
        """
    }

    func sendMessage(profile: UserProfile) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
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
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func sendQuickQuestion(_ question: String, profile: UserProfile) {
        inputText = question
        sendMessage(profile: profile)
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}
