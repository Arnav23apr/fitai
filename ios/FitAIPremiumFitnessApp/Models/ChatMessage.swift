import Foundation

nonisolated struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    nonisolated enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
