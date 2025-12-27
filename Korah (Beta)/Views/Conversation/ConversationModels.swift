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
        
        // Clean assistant message
        var cleaned = lastMessage.content
        
        // Try to extract meaningful text from JSON if it exists
        if cleaned.contains("{") && cleaned.contains("}") {
            // Try to parse as JSON and extract summary or title
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let summary = json["summary"] as? String, !summary.isEmpty {
                    cleaned = summary
                } else if let title = json["title"] as? String, !title.isEmpty {
                    cleaned = title
                } else {
                    cleaned = "Response"
                }
            } else {
                // If JSON parsing fails, just remove the JSON content
                if let openBrace = cleaned.firstIndex(of: "{"),
                   let closeBrace = cleaned.lastIndex(of: "}") {
                    cleaned.removeSubrange(openBrace...closeBrace)
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.isEmpty {
                        cleaned = "Response"
                    }
                }
            }
        }
        
        let maxLength = 100
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength)) + "..."
        }
        return cleaned
    }
}
