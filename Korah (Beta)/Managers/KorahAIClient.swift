import Foundation

// MARK: - Gemini chat proxy client (/api/r, OpenAI-shaped I/O)

struct AIChatMessage {
    let role: String     // "system" | "user" | "assistant"
    let content: String
}

enum KorahAIError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid AI endpoint."
        case .badStatus(let code):
            return code == 429
                ? "Too many requests. Please wait a moment."
                : "AI service error (\(code))."
        case .emptyResponse: return "The AI returned an empty response."
        }
    }
}

final class KorahAIClient: Sendable {
    static let shared = KorahAIClient()
    private init() {}

    /// Non-streaming completion. Set `jsonResponse` to request
    /// `response_format: {type: "json_object"}` (Gemini JSON mime type).
    func complete(messages: [AIChatMessage],
                  temperature: Double = 0.3,
                  jsonResponse: Bool = false) async throws -> String {
        guard let url = URL(string: APIConfig.chatURL) else { throw KorahAIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": APIConfig.chatModel,
            "temperature": temperature,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
        ]
        if jsonResponse {
            body["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KorahAIError.emptyResponse }
        guard (200...299).contains(http.statusCode) else { throw KorahAIError.badStatus(http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw KorahAIError.emptyResponse
        }
        return content
    }

    /// Non-streaming completion with an attached image (base64 data URL).
    /// Sends OpenAI-style content parts, which /api/r converts to Gemini
    /// inlineData for vision. Used for practice report score extraction.
    func completeWithImage(system: String,
                           userText: String,
                           imageDataURL: String,
                           temperature: Double = 0.1,
                           jsonResponse: Bool = true) async throws -> String {
        guard let url = URL(string: APIConfig.chatURL) else { throw KorahAIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": APIConfig.chatModel,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": userText],
                    ["type": "image_url", "image_url": ["url": imageDataURL]],
                ]],
            ],
            "stream": false,
        ]
        if jsonResponse {
            body["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw KorahAIError.emptyResponse }
        guard (200...299).contains(http.statusCode) else { throw KorahAIError.badStatus(http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw KorahAIError.emptyResponse
        }
        return content
    }

    /// SSE streaming completion. `onDelta` receives (delta, accumulated).
    /// Returns the full accumulated text.
    @discardableResult
    func stream(messages: [AIChatMessage],
                temperature: Double = 0.3,
                onDelta: @escaping @Sendable (String, String) -> Void) async throws -> String {
        guard let url = URL(string: APIConfig.chatURL) else { throw KorahAIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "model": APIConfig.chatModel,
            "temperature": temperature,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw KorahAIError.emptyResponse }
        guard (200...299).contains(http.statusCode) else { throw KorahAIError.badStatus(http.statusCode) }

        var full = ""
        for try await line in bytes.lines {
            if Task.isCancelled { break }
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String, !content.isEmpty else { continue }
            full += content
            onDelta(content, full)
        }
        guard !full.isEmpty else { throw KorahAIError.emptyResponse }
        return full
    }
}
