import Foundation

class CoachService {
    private let aiService = AIService()

    func sendMessage(messages: [ChatMessage], systemContext: String) async throws -> String {
        var apiMessages: [ChatAPIMessage] = [
            ChatAPIMessage(role: "system", text: systemContext)
        ]

        for msg in messages {
            apiMessages.append(ChatAPIMessage(role: msg.role.rawValue, text: msg.content))
        }

        do {
            return try await aiService.chat(messages: apiMessages)
        } catch let error as AIError {
            throw CoachError.serverError(error.localizedDescription)
        } catch {
            throw CoachError.networkError
        }
    }
}

nonisolated enum CoachError: Error, Sendable, LocalizedError {
    case invalidURL
    case networkError
    case serverError(String)
    case emptyResponse

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .networkError: return "Network error occurred"
        case .serverError(let msg): return msg
        case .emptyResponse: return "Empty response from coach"
        }
    }
}
