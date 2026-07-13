import Foundation

/// Canonical Korah backend (korah-web deployment on Vercel).
/// Serves /api/r (Gemini chat proxy), /api/sat/q|qi|s (College Board bank),
/// and /api/generate-study-item.
enum APIConfig {
    /// Production base URL. Alternate: https://korah-web.vercel.app
    static let baseURL: String = "https://www.korah.app"

    /// Gemini chat proxy (OpenAI-shaped request/response, SSE streaming).
    static let chatURL: String = "\(baseURL)/api/r"

    /// Default model served by /api/r.
    static let chatModel: String = "gemini-2.5-flash"

    /// SAT question bank endpoints (public, CDN-cached).
    static let satQuestionsURL: String = "\(baseURL)/api/sat/q"
    static let satQuestionDetailURL: String = "\(baseURL)/api/sat/qi"
    static let satStatsURL: String = "\(baseURL)/api/sat/s"

    /// AI study generation endpoint.
    static let generateStudyItemURL: String = "\(baseURL)/api/generate-study-item"

    // MARK: - Legacy compatibility

    /// Alias kept so existing call sites read naturally; same as `chatURL`.
    static let chatCompletionsURL: String = chatURL

    /// Voice endpoints still served only by the old beta deployment
    /// (korah-web has no /api/transcribe or /api/speak).
    static let legacyBaseURL: String = "https://korah-beta.vercel.app"
    static let transcriptionsURL: String = "\(legacyBaseURL)/api/transcribe"
    static let speechURL: String = "\(legacyBaseURL)/api/speak"
}
