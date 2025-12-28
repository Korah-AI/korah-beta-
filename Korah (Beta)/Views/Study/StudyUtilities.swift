import Foundation

/// Shared utilities for the Study module
enum StudyUtilities {
    
    // MARK: - JSON Utilities
    
    /// Extracts a JSON object from text that might contain markdown code fences or other formatting
    static func extractJSONObject(from text: String) -> String? {
        // First try: check if entire string is valid JSON
        if let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return text
        }
        
        // Second try: extract content between first { and last }
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return nil
        }
        
        let substring = text[startIndex...endIndex]
        let extracted = String(substring)
        
        // Validate extracted JSON
        if let data = extracted.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return extracted
        }
        
        return nil
    }
    
    // MARK: - Practice Test Generation
    
    /// Generates practice test questions from flashcard set
    static func generatePracticeTestQuestions(from cards: [Flashcard], minCards: Int = 4) -> Result<[PracticeTestQuestion], StudyError> {
        guard cards.count >= minCards else {
            return .failure(.insufficientCards(required: minCards, actual: cards.count))
        }
        
        let shuffledCards = cards.shuffled()
        let allBacks = cards.map { $0.back }
        var questions: [PracticeTestQuestion] = []
        
        for card in shuffledCards {
            let correct = card.back
            var wrongs = allBacks.filter { $0 != correct }.shuffled()
            var options: [String] = [correct]
            
            // Add up to 3 wrong answers
            options.append(contentsOf: wrongs.prefix(3))
            
            // Ensure we have 4 options (fill with random if needed)
            while options.count < 4 {
                if let random = allBacks.randomElement() {
                    options.append(random)
                }
            }
            
            options.shuffle()
            let correctIndex = options.firstIndex(of: correct) ?? 0
            
            let question = PracticeTestQuestion(
                prompt: card.front,
                options: options,
                correctIndex: correctIndex
            )
            questions.append(question)
        }
        
        return .success(questions)
    }
    
    /// Generates a practice test title
    static func generateTestTitle(from source: String, customTitle: String? = nil, prefix: String = "Practice Test") -> String {
        if let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return "\(prefix) from \(source)"
    }
    
    // MARK: - Error Handling
    
    /// Maps HTTP status codes to user-friendly error messages
    static func errorMessage(for httpStatusCode: Int, responseData: Data?) -> String {
        switch httpStatusCode {
        case 400:
            return "Bad request. Please check your input and try again."
        case 401:
            return "Authentication failed. Please check your API configuration."
        case 403:
            return "Access denied. Please verify your API permissions."
        case 429:
            return "Too many requests. Please wait a moment and try again."
        case 500...599:
            return "Server error. Please try again later."
        default:
            // Try to extract error message from response
            if let data = responseData,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            return "HTTP Error \(httpStatusCode). Please try again."
        }
    }
    
    /// Provides user-friendly network error messages
    static func errorMessage(for error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection. Please check your network and try again."
        case NSURLErrorTimedOut:
            return "Request timed out. Please check your connection and try again."
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
            return "Cannot connect to server. Please try again later."
        case NSURLErrorNetworkConnectionLost:
            return "Network connection lost. Please try again."
        default:
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Error Types

enum StudyError: LocalizedError {
    case insufficientCards(required: Int, actual: Int)
    case invalidJSON
    case networkError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .insufficientCards(let required, let actual):
            return "Need at least \(required) flashcards to create a test. You have \(actual)."
        case .invalidJSON:
            return "Failed to parse AI response. The generated content was not in the expected format."
        case .networkError(let message):
            return message
        case .unknownError:
            return "An unknown error occurred. Please try again."
        }
    }
}
