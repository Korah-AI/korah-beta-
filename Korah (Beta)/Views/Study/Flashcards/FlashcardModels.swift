import Foundation

struct Flashcard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var front: String
    var back: String
    var lastOpenedAt: Date? = nil
    
    // Spaced repetition metadata
    var studyCount: Int = 0
    var lastStudiedAt: Date? = nil
    var difficultyLevel: DifficultyLevel = .new
    var nextReviewDate: Date? = nil
    
    enum DifficultyLevel: String, Codable {
        case new = "new"
        case learning = "learning"
        case review = "review"
        case mastered = "mastered"
    }
    
    /// Mark this card as studied and update spaced repetition metadata
    mutating func markStudied(difficulty: DifficultyLevel? = nil) {
        studyCount += 1
        lastStudiedAt = Date()
        
        if let difficulty = difficulty {
            difficultyLevel = difficulty
        } else {
            // Auto-progress difficulty based on study count
            switch studyCount {
            case 1:
                difficultyLevel = .learning
            case 2...4:
                difficultyLevel = .review
            case 5...:
                difficultyLevel = .mastered
            default:
                break
            }
        }
        
        // Calculate next review date using simple spaced repetition
        let intervalDays: Double
        switch difficultyLevel {
        case .new:
            intervalDays = 1
        case .learning:
            intervalDays = 3
        case .review:
            intervalDays = 7
        case .mastered:
            intervalDays = 14
        }
        
        nextReviewDate = Calendar.current.date(byAdding: .day, value: Int(intervalDays), to: Date())
    }
    
    /// Check if this card is due for review
    var isDueForReview: Bool {
        guard let nextReview = nextReviewDate else { return true }
        return Date() >= nextReview
    }
}

struct FlashcardSet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var cards: [Flashcard] = []
    var lastOpenedAt: Date? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

extension FlashcardSet {
    static let sample: FlashcardSet = FlashcardSet(
        title: "Spanish Basics",
        cards: [
            Flashcard(front: "Hola", back: "Hello"),
            Flashcard(front: "Gracias", back: "Thank you"),
            Flashcard(front: "Adiós", back: "Goodbye")
        ]
    )

    static let samples: [FlashcardSet] = [
        .sample,
        FlashcardSet(title: "Math Formulas", cards: [
            Flashcard(front: "Area of circle", back: "πr²"),
            Flashcard(front: "Quadratic Formula", back: "x = (-b ± √(b²-4ac)) / 2a")
        ])
    ]
}
