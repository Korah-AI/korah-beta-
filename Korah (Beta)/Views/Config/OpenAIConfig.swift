import Foundation

enum OpenAIConfig {
    // Vercel serverless proxy (API key stored securely on Vercel)
    static let proxyBaseURL: String = "https://korah-beta.vercel.app"
    
    // API endpoints (using Vercel proxy)
    static let chatCompletionsURL: String = "\(proxyBaseURL)/api/proxy"
    static let transcriptionsURL: String = "\(proxyBaseURL)/api/transcribe"
    static let speechURL: String = "\(proxyBaseURL)/api/speak"
    
    // No bearer token needed - API key is stored securely on Vercel
    static var bearerToken: String {
        return "" // Not used when proxying through Vercel
    }
}
