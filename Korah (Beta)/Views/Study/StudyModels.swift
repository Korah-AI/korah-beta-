import Foundation

struct StudyGuide: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var lastOpenedAt: Date? = nil
    var createdAt: Date
    
    // Study tracking metadata
    var reviewCount: Int = 0
    var lastReviewedAt: Date? = nil

    init(id: UUID = UUID(), title: String, content: String, lastOpenedAt: Date? = nil, createdAt: Date = Date(), reviewCount: Int = 0, lastReviewedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.lastOpenedAt = lastOpenedAt
        self.createdAt = createdAt
        self.reviewCount = reviewCount
        self.lastReviewedAt = lastReviewedAt
    }
    
    /// Mark this guide as reviewed
    mutating func markReviewed() {
        reviewCount += 1
        lastReviewedAt = Date()
    }
}

extension StudyGuide {
    static let sampleData: [StudyGuide] = [
        StudyGuide(title: "Swift Basics", content: "Learn about variables, constants, and basic data types in Swift."),
        StudyGuide(title: "Protocols and Extensions", content: "Understand how protocols define interfaces and how extensions add functionality."),
        StudyGuide(title: "SwiftUI Introduction", content: "Discover how to build UI declaratively using SwiftUI framework.")
    ]
}

struct PracticeTestQuestion: Identifiable, Codable, Equatable {
    var id: UUID
    var prompt: String
    var options: [String]
    var correctIndex: Int

    init(id: UUID = UUID(), prompt: String, options: [String], correctIndex: Int) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
    }
}

struct PracticeTest: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var questions: [PracticeTestQuestion]
    var lastOpenedAt: Date? = nil
    var createdAt: Date
    
    // Test performance tracking
    var attemptCount: Int = 0
    var lastAttemptAt: Date? = nil
    var bestScore: Int? = nil
    var lastScore: Int? = nil

    init(id: UUID = UUID(), title: String, questions: [PracticeTestQuestion], lastOpenedAt: Date? = nil, createdAt: Date = Date(), attemptCount: Int = 0, lastAttemptAt: Date? = nil, bestScore: Int? = nil, lastScore: Int? = nil) {
        self.id = id
        self.title = title
        self.questions = questions
        self.lastOpenedAt = lastOpenedAt
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.bestScore = bestScore
        self.lastScore = lastScore
    }
    
    /// Record a test attempt with score
    mutating func recordAttempt(score: Int) {
        attemptCount += 1
        lastAttemptAt = Date()
        lastScore = score
        
        if let best = bestScore {
            bestScore = max(best, score)
        } else {
            bestScore = score
        }
    }
    
    /// Get score percentage for last attempt
    var lastScorePercentage: Double? {
        guard let score = lastScore, !questions.isEmpty else { return nil }
        return Double(score) / Double(questions.count) * 100
    }
    
    /// Get best score percentage
    var bestScorePercentage: Double? {
        guard let score = bestScore, !questions.isEmpty else { return nil }
        return Double(score) / Double(questions.count) * 100
    }
}

extension PracticeTest {
    static let sampleData: [PracticeTest] = [
        PracticeTest(
            title: "Swift Basics Test",
            questions: [
                PracticeTestQuestion(
                    prompt: "Which keyword declares a constant in Swift?",
                    options: ["var", "let", "const", "final"],
                    correctIndex: 1
                ),
                PracticeTestQuestion(
                    prompt: "What is the type of 3.14?",
                    options: ["Int", "Double", "String", "Float"],
                    correctIndex: 1
                )
            ]
        ),
        PracticeTest(
            title: "SwiftUI Fundamentals",
            questions: [
                PracticeTestQuestion(
                    prompt: "Which protocol must a SwiftUI view conform to?",
                    options: ["UIViewController", "View", "Delegate", "ObservableObject"],
                    correctIndex: 1
                ),
                PracticeTestQuestion(
                    prompt: "What modifier is used to add padding to a view?",
                    options: [".frame()", ".padding()", ".background()", ".cornerRadius()"],
                    correctIndex: 1
                ),
                PracticeTestQuestion(
                    prompt: "How do you declare a state variable in SwiftUI?",
                    options: ["@State var", "var", "let", "@Published var"],
                    correctIndex: 0
                )
            ]
        )
    ]
}
