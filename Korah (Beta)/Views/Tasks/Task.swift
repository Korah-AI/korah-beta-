import Foundation

enum TaskDifficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Med"
    case hard = "Hard"
    
    var emoji: String {
        switch self {
        case .easy: return "🟢"
        case .medium: return "🟡"
        case .hard: return "🔴"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "yellow"
        case .hard: return "red"
        }
    }
}

struct StudyTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var dueDate: Date
    var difficulty: TaskDifficulty
    
    init(id: UUID = UUID(), title: String, description: String, dueDate: Date, difficulty: TaskDifficulty = .medium) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.difficulty = difficulty
    }
}
