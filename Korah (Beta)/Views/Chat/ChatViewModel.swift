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
        Haptics.medium()
    }
    
    /// Copy message content to clipboard
    func copyMessage(_ message: ChatMessage) {
        let text = extractReadableText(from: message.content)
        UIPasteboard.general.string = text
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
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
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
               let base64 = img.jpegData(compressionQuality: 0.8)?.base64EncodedString() {
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
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "temperature": 0.3,
            "max_tokens": 1000,
            "stream": true,
            "response_format": ["type": "json_object"]
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
        """
        You are Korah, a friendly tutor for kids. Never give final answers to homework outright; guide step-by-step.
        Always respond with PURE JSON (no backticks, no code fences), matching this schema:

        {
          "kind": "tutor",
          "title": string,
          "summary": string,
          "steps": [string],
          "hints": [string],
          "questions": [string],
          "footer": string (optional)
        }

        Rules:
        - Keep it kid-friendly, concise, and actionable.
        - Do NOT include any non-JSON text.
        - If the user asks for direct answers, redirect with hints in JSON.
        - REMINDER: Students can ask you to create flashcards, study guides, or practice tests.
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
    
    private func updateSuggestions() {
        guard let lastMessage = messages.last(where: { $0.role == .assistant }) else {
            suggestions = ChatSuggestion.starters
            return
        }
        
        // Try to extract questions from formatted response
        if let response = lastMessage.content.decodeKorahResponse(),
           let questions = response.questions, !questions.isEmpty {
            suggestions = questions.prefix(3).map { ChatSuggestion($0) }
        } else {
            suggestions = ChatSuggestion.followUps
        }
    }
    
    private func extractReadableText(from content: String) -> String {
        guard let response = content.decodeKorahResponse() else {
            return content
        }
        
        var text = ""
        
        if let title = response.title, !title.isEmpty {
            text += title + "\n\n"
        }
        
        if let summary = response.summary, !summary.isEmpty {
            text += summary + "\n\n"
        }
        
        if let steps = response.steps, !steps.isEmpty {
            text += "Steps:\n"
            for (index, step) in steps.enumerated() {
                text += "\(index + 1). \(step)\n"
            }
            text += "\n"
        }
        
        if let hints = response.hints, !hints.isEmpty {
            text += "Hints:\n"
            for hint in hints {
                text += "• \(hint)\n"
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
