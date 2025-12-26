import Foundation

struct Flashcard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var front: String
    var back: String
    var lastOpenedAt: Date? = nil
}

struct FlashcardSet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var cards: [Flashcard] = []
    var lastOpenedAt: Date? = nil
    var createdAt: Date = Date()
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
