import Foundation

struct APIErrorHandler {
    /// Handles HTTP error responses and returns a user-friendly message
    static func handleError(statusCode: Int, data: Data?) -> String {
        // Try to parse rate limit error first
        if statusCode == 429, let data = data {
            if let rateLimitError = try? JSONDecoder().decode(RateLimitError.self, from: data) {
                return rateLimitError.userFriendlyMessage
            }
            // Fallback if JSON parsing fails
            return "Daily limit reached. Please try again later."
        }
        
        // Handle other error codes
        switch statusCode {
        case 401:
            return "Authentication error. Please contact support."
        case 429:
            return "Too many requests. Please wait a moment and try again."
        case 500...599:
            return "Server error. Please try again in a few minutes."
        default:
            return "An error occurred. Please try again."
        }
    }
}
