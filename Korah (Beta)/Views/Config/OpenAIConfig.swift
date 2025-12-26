import Foundation

enum OpenAIConfig {
    static let apiKey: String = "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"

    static var bearerToken: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "Bearer \(apiKey)"
    }
}
