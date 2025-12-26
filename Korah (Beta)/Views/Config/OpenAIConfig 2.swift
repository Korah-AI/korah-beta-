import Foundation

enum OpenAIConfiguration {
    static let apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

    static var bearerToken: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "Bearer \(apiKey)"
    }
}
