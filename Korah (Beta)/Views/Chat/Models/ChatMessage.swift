import SwiftUI
import UIKit

// MARK: - Message Role

/// Role of a chat message participant
enum MessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

// MARK: - Message State

/// State of a message (for streaming)
enum MessageState: Equatable {
    case idle
    case streaming
    case complete
    case error(String)
}

// MARK: - Chat Message

/// A single message in a conversation
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var image: UIImage?
    var state: MessageState
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        image: UIImage? = nil,
        state: MessageState = .complete
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.image = image
        self.state = state
    }
    
    /// Whether this message is from the user
    var isUser: Bool { role == .user }
    
    /// Whether this message is from the assistant
    var isAssistant: Bool { role == .assistant }
    
    /// Whether the message is currently streaming
    var isStreaming: Bool {
        if case .streaming = state { return true }
        return false
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.state == rhs.state
    }
}

// MARK: - Formatted Response (Korah JSON)

/// Structured response format from Korah AI
struct KorahResponse: Codable {
    let kind: String?
    let title: String?
    let summary: String?
    let steps: [String]?
    let hints: [String]?
    let questions: [String]?
    let footer: String?
}

extension String {
    /// Attempt to decode this string as a KorahResponse
    func decodeKorahResponse() -> KorahResponse? {
        // Try direct decode
        if let data = self.data(using: .utf8),
           let response = try? JSONDecoder().decode(KorahResponse.self, from: data) {
            return response
        }
        
        // Try extracting JSON from content
        guard let start = self.firstIndex(of: "{"),
              let end = self.lastIndex(of: "}") else { return nil }
        
        let jsonSubstring = self[start...end]
        guard let data = String(jsonSubstring).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(KorahResponse.self, from: data)
    }
}

// MARK: - ChatMessage Extensions

extension ChatMessage {
    /// Convert to ConversationMessage for persistence
    func toConversationMessage() -> ConversationMessage {
        ConversationMessage(
            id: id,
            role: role.rawValue,
            content: content,
            timestamp: timestamp,
            imageFileName: nil
        )
    }
}

extension ConversationMessage {
    /// Convert from ConversationMessage to ChatMessage
    func toChatMessage(image: UIImage? = nil) -> ChatMessage {
        ChatMessage(
            id: id,
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            timestamp: timestamp,
            image: image,
            state: .complete
        )
    }
}

// MARK: - Quick Suggestions

/// Suggestion chip for contextual follow-ups
struct ChatSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String?
    
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }
}

// MARK: - Default Suggestions

extension ChatSuggestion {
    static let starters: [ChatSuggestion] = [
        ChatSuggestion("Help me solve this problem", icon: "lightbulb"),
        ChatSuggestion("Explain this step by step", icon: "list.number"),
        ChatSuggestion("Check my homework answer", icon: "checkmark.circle"),
        ChatSuggestion("What can you help me learn?", icon: "book")
    ]
    
    static let followUps: [ChatSuggestion] = [
        ChatSuggestion("Explain deeper", icon: "magnifyingglass"),
        ChatSuggestion("Give me an example", icon: "lightbulb"),
        ChatSuggestion("Practice problem", icon: "pencil.and.outline")
    ]
}
