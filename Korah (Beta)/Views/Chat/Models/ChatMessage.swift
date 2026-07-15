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
        ChatSuggestion("Solve this SAT problem with Desmos", icon: "function"),
        ChatSuggestion("Explain this step by step", icon: "list.number"),
        ChatSuggestion("Quiz me on SAT math", icon: "checkmark.circle"),
        ChatSuggestion("How is the digital SAT scored?", icon: "chart.line.uptrend.xyaxis")
    ]

    static let followUps: [ChatSuggestion] = [
        ChatSuggestion("Explain deeper", icon: "magnifyingglass"),
        ChatSuggestion("Show the Desmos way", icon: "function"),
        ChatSuggestion("Give me a similar problem", icon: "pencil.and.outline"),
        ChatSuggestion("Why is this the answer?", icon: "questionmark.circle")
    ]
}
