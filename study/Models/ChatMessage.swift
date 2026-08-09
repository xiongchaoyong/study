import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String       // "user" | "assistant" | "error"
    var content: String
    var createdAt: Date

    init(role: String, content: String, createdAt: Date = Date()) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
