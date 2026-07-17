import SwiftUI
import Combine

// MARK: - Chat ViewModel

/// Observable ViewModel for chat functionality with streaming support
@MainActor
@Observable
final class ChatViewModel {
    
    // MARK: - Published State
    
    /// All messages in the current conversation
    var messages: [ChatMessage] = []
    
    /// Current user input text
    var inputText: String = ""
    
    /// Selected image for sending
    var selectedImage: UIImage?
    
    /// Whether a response is being generated
    var isLoading: Bool = false
    
    /// Whether the assistant is currently streaming
    var isStreaming: Bool = false
    
    /// Error message to display
    var errorMessage: String?
    
    /// Current suggestions based on context
    var suggestions: [ChatSuggestion] = ChatSuggestion.starters
    
    /// Whether the user is at the bottom of the scroll view
    var isAtBottom: Bool = true
    
    /// ID of the last message (for scrolling)
    var lastMessageID: UUID?
    
    // MARK: - Private State
    
    private var streamTask: Task<Void, Never>?
    private var updateBuffer: String = ""
    private var lastUpdateTime: Date = Date()
    private let updateThrottle: TimeInterval = 0.05 // 50ms throttle
    private var currentConversation: Conversation?
    
    // MARK: - Computed Properties
    
    /// Whether the send button should be enabled
    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }
    
    /// Whether there's an assistant response to act on
    var hasAssistantResponse: Bool {
        messages.last?.role == .assistant
    }
    
    /// Check if conversation is empty
    var isEmpty: Bool {
        messages.isEmpty
    }
    
    // MARK: - Actions
    
    /// Send the current input as a message
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImage != nil else { return }
        
        // Create user message
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            image: selectedImage
        )
        
        // Add to messages
        messages.append(userMessage)
        lastMessageID = userMessage.id
        
        // Clear input
        inputText = ""
        let imageToSend = selectedImage
        selectedImage = nil
        
        // Provide haptic feedback
        Haptics.light()
        
        // Start streaming response
        Task {
            await fetchStreamingResponse(image: imageToSend)
        }
    }
    
    /// Send a suggestion as a message
    func sendSuggestion(_ suggestion: ChatSuggestion) {
        inputText = suggestion.text
        sendMessage()
    }
    
    /// Stop the current streaming response
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isLoading = false
        
        // Mark the last message as complete
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .assistant {
            messages[lastIndex].state = .complete
        }
        
        Haptics.medium()
    }
    
    /// Retry the last failed message
    func retryLastMessage() {
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) else { return }
        
        // Remove any assistant messages after the last user message
        messages = Array(messages[...lastUserIndex])
        
        // Re-fetch response
        Task {
            await fetchStreamingResponse(image: nil)
        }
    }
    
    /// Clear all messages
    func clearChat() {
        messages.removeAll()
        suggestions = ChatSuggestion.starters
        errorMessage = nil
        currentConversation = nil
        Haptics.medium()
    }

    /// Load a saved conversation from history into the current chat.
    /// Subsequent messages update the same Firestore document.
    func loadConversation(_ conversation: Conversation) {
        stopStreaming()
        messages = conversation.messages.map { $0.toChatMessage() }
        currentConversation = conversation
        lastMessageID = messages.last?.id
        errorMessage = nil
        updateSuggestions()
        Haptics.light()
    }
    
    /// Copy message content to clipboard
    func copyMessage(_ message: ChatMessage) {
        UIPasteboard.general.string = message.content
        Haptics.success()
    }
    
    // MARK: - Streaming Response
    
    private func fetchStreamingResponse(image: UIImage?) async {
        isLoading = true
        isStreaming = true
        errorMessage = nil
        
        // Create placeholder assistant message
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: "",
            state: .streaming
        )
        messages.append(assistantMessage)
        lastMessageID = assistantMessage.id
        
        guard let assistantIndex = messages.indices.last else { return }
        
        // Build API request
        guard let url = URL(string: APIConfig.chatCompletionsURL) else {
            handleError("Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
        // Build messages payload
        let systemPrompt = buildSystemPrompt()
        var apiMessages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        
        for message in messages.dropLast() { // Exclude the placeholder
            if let img = message.image,
               let base64 = img.compressedBase64() {
                var content: [[String: Any]] = []
                if !message.content.isEmpty {
                    content.append(["type": "text", "text": message.content])
                }
                content.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                ])
                apiMessages.append(["role": message.role.rawValue, "content": content])
            } else {
                apiMessages.append(["role": message.role.rawValue, "content": message.content])
            }
        }
        
        // Matches the web app (korah-chat.js callChatApi): plain markdown
        // streaming, temperature 0.7, no JSON response_format.
        let body: [String: Any] = [
            "model": APIConfig.chatModel,
            "messages": apiMessages,
            "temperature": 0.7,
            "stream": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Start streaming
        streamTask = Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    handleError("Invalid response")
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    handleHTTPError(statusCode: httpResponse.statusCode)
                    return
                }
                
                var fullContent = ""
                
                for try await line in bytes.lines {
                    // Check for cancellation
                    if Task.isCancelled { break }
                    
                    // Parse SSE data
                    guard line.hasPrefix("data: ") else { continue }
                    let data = String(line.dropFirst(6))
                    
                    if data == "[DONE]" { break }
                    
                    guard let jsonData = data.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let delta = choices.first?["delta"] as? [String: Any],
                          let content = delta["content"] as? String else { continue }
                    
                    fullContent += content
                    
                    // Throttled update
                    await throttledUpdate(content: fullContent, at: assistantIndex)
                }
                
                // Final update
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].content = fullContent
                        messages[assistantIndex].state = .complete
                    }
                    isLoading = false
                    isStreaming = false
                    updateSuggestions()
                    persistConversation()
                }
                
            } catch {
                if !Task.isCancelled {
                    handleError(error.localizedDescription)
                }
            }
        }
    }
    
    private func throttledUpdate(content: String, at index: Int) async {
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) >= updateThrottle {
            await MainActor.run {
                if index < messages.count {
                    messages[index].content = content
                }
            }
            lastUpdateTime = now
        }
    }
    
    // MARK: - Helpers
    
    private func buildSystemPrompt() -> String {
        // Mirrors the web app's `sat` mode prompt (korah-chat.js MODE_SYSTEM_PROMPTS.sat):
        // plain Markdown + KaTeX, SAT-focused, no JSON.
        """
        ABOUT KORAH: Created by Oscar Euceda, a high school programmer, Korah is a free academic resource that helps students receive quality education at the click of a button.

        You are Korah, an expert digital SAT tutor. Your teaching style:
        - Focus on speed, accuracy, and test-taking strategies
        - Teach students to recognize the question patterns the SAT repeats
        - For math, teach the fastest path to the answer — mention the Desmos shortcut in one line only when it's genuinely quicker
        - Cover all SAT sections: Math (Algebra, Advanced Math, Problem-Solving & Data Analysis, Geometry) and Reading & Writing (evidence, grammar, vocabulary-in-context)

        TEACHING APPROACH:
        - Be brief. A short answer the student actually reads beats a thorough one they skim.
        - Solve it in 3-5 numbered steps max, then state the final answer on its own line.
        - One approach per answer. No alternate methods, extra tips, practice suggestions, or recap sections unless the student asks.
        - It's a chat: end after the answer, and let the student ask the follow-up.

        KaTeX delimiter policy (REQUIRED for all math):
        - Inline math: $...$ (single dollar signs)
        - Display math: $$...$$ (double dollar signs)
        - NEVER use \\(...\\), \\[...\\], or bare math without delimiters

        Format replies as clean Markdown (headings, **bold**, and lists where helpful).
        """
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        isLoading = false
        isStreaming = false
        
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .assistant {
            messages[lastIndex].state = .error(message)
            messages[lastIndex].content = "I had trouble responding. Please try again."
        }
    }
    
    private func handleHTTPError(statusCode: Int) {
        let message: String
        switch statusCode {
        case 401:
            message = "Authentication issue. Please contact support."
        case 429:
            message = "Too many requests. Please wait a moment."
        case 500...599:
            message = "Server issue. Please try again later."
        default:
            message = "Something went wrong. Please try again."
        }
        handleError(message)
    }
    
    // MARK: - Conversation Persistence

    private func persistConversation() {
        let conversationMessages = messages.compactMap { msg -> ConversationMessage? in
            guard msg.state == .complete || msg.role == .user else { return nil }
            return ConversationMessage(
                id: msg.id,
                role: msg.role.rawValue,
                content: msg.content,
                timestamp: Date(),
                imageFileName: nil
            )
        }
        guard !conversationMessages.isEmpty else { return }

        if var existing = currentConversation {
            existing.messages = conversationMessages
            existing.updatedAt = Date()
            currentConversation = existing
            try? FirestoreConversationService.shared.saveConversation(existing)
        } else {
            let firstUserContent = messages.first(where: { $0.role == .user })?.content ?? "Chat"
            let title = String(firstUserContent.prefix(50))
            let conversation = Conversation(
                title: title,
                type: .chat,
                messages: conversationMessages
            )
            currentConversation = conversation
            try? FirestoreConversationService.shared.saveConversation(conversation)
        }
    }

    private func updateSuggestions() {
        // Derive follow-up chips from the latest assistant reply, keyed off
        // SAT topics — mirrors the web's `generateContextualSuggestions`.
        guard let last = messages.last(where: { $0.role == .assistant })?.content,
              !last.isEmpty else {
            suggestions = ChatSuggestion.starters
            return
        }
        suggestions = ChatViewModel.contextualSuggestions(for: last)
    }

    /// Keyword-driven SAT follow-ups for the most recent assistant response.
    static func contextualSuggestions(for response: String) -> [ChatSuggestion] {
        let r = response.lowercased()

        func has(_ terms: String...) -> Bool { terms.contains { r.contains($0) } }

        if has("desmos", "graph", "regression", "plot", "intersection") {
            return [
                ChatSuggestion("Walk me through the Desmos steps", icon: "function"),
                ChatSuggestion("Solve it without a calculator", icon: "pencil.and.outline"),
                ChatSuggestion("Give me a similar problem", icon: "plus.forwardslash.minus")
            ]
        }
        if has("quadratic", "parabola", "x²", "x^2", "vertex", "factor") {
            return [
                ChatSuggestion("How do I find the vertex?", icon: "chart.dots.scatter"),
                ChatSuggestion("What's the discriminant?", icon: "questionmark.circle"),
                ChatSuggestion("Factor this step by step", icon: "list.number")
            ]
        }
        if has("slope", "linear", "y = mx", "y=mx", "line of best fit") {
            return [
                ChatSuggestion("What does the slope mean here?", icon: "chart.line.uptrend.xyaxis"),
                ChatSuggestion("Find the y-intercept", icon: "arrow.down.to.line"),
                ChatSuggestion("Give me a harder one", icon: "flame")
            ]
        }
        if has("system", "elimination", "substitution", "two equations") {
            return [
                ChatSuggestion("Show the Desmos shortcut", icon: "function"),
                ChatSuggestion("When is there no solution?", icon: "xmark.circle"),
                ChatSuggestion("Give me a similar problem", icon: "plus.forwardslash.minus")
            ]
        }
        if has("exponential", "growth", "decay", "percent", "interest") {
            return [
                ChatSuggestion("Growth vs. decay — how to tell?", icon: "arrow.up.arrow.down"),
                ChatSuggestion("Set up the equation", icon: "function"),
                ChatSuggestion("Practice problem, please", icon: "pencil.and.outline")
            ]
        }
        if has("triangle", "circle", "angle", "geometry", "area", "radius") {
            return [
                ChatSuggestion("Which formula do I use?", icon: "ruler"),
                ChatSuggestion("Draw it out for me", icon: "scribble.variable"),
                ChatSuggestion("Give me a similar problem", icon: "plus.forwardslash.minus")
            ]
        }
        if has("evidence", "passage", "reading", "author", "main idea", "tone") {
            return [
                ChatSuggestion("How do I spot the evidence?", icon: "text.magnifyingglass"),
                ChatSuggestion("Eliminate wrong answers", icon: "xmark.circle"),
                ChatSuggestion("Give me a practice passage", icon: "text.book.closed")
            ]
        }
        if has("grammar", "comma", "punctuation", "clause", "verb", "writing") {
            return [
                ChatSuggestion("Explain the grammar rule", icon: "text.badge.checkmark"),
                ChatSuggestion("Show me a tricky example", icon: "exclamationmark.triangle"),
                ChatSuggestion("Quiz me on this", icon: "checklist")
            ]
        }
        if has("score", "pacing", "time", "guess", "strategy") {
            return [
                ChatSuggestion("Make me a study plan", icon: "calendar"),
                ChatSuggestion("Best guessing strategy?", icon: "dice"),
                ChatSuggestion("What are common traps?", icon: "exclamationmark.triangle")
            ]
        }

        // Fallback: general SAT follow-ups.
        return ChatSuggestion.followUps
    }
}
