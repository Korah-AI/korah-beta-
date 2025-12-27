import Foundation
import UIKit

enum ConversationType: String, Codable {
    case chat
    case scan
}

struct ConversationMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    let imageFileName: String?
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date, imageFileName: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.imageFileName = imageFileName
    }
}

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    let type: ConversationType
    var messages: [ConversationMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String, type: ConversationType, messages: [ConversationMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.type = type
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var messageCount: Int {
        messages.count
    }
    
    var lastMessagePreview: String {
        guard let lastMessage = messages.last else { return "" }
        if lastMessage.role == "user" {
            return lastMessage.content.isEmpty ? "Image" : lastMessage.content
        }
        return lastMessage.content.prefix(100) + (lastMessage.content.count > 100 ? "..." : "")
    }
}
