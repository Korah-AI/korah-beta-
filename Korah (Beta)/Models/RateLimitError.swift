import Foundation

struct RateLimitError: Codable {
    let error: String
    let message: String
    let remaining: Int
    let resetTime: String
    let current: Int
    let limit: Int
    
    var resetDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: resetTime)
    }
    
    var userFriendlyMessage: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        if let date = resetDate {
            let timeString = formatter.string(from: date)
            return "Daily limit reached. Your limit resets at \(timeString). You've used \(current) of \(limit) tokens today."
        } else {
            return "Daily limit reached. Please try again later."
        }
    }
}
