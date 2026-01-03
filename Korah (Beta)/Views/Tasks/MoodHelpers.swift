import Foundation

struct FocusExercise: Identifiable {
    let id = UUID()
    let title: String
    let duration: String
    let icon: String
}

class MoodHelpers {
    /// Get tasks filtered and sorted based on current mood
    static func getRecommendedTasks(for mood: String, tasks: [Task]) -> [Task] {
        switch mood {
        case "🟢": // Very focused
            // Show harder tasks first
            return tasks.sorted { $0.difficulty.rawValue > $1.difficulty.rawValue }
        case "🟡": // Moderately focused
            // Show medium and easy tasks
            return tasks.filter { $0.difficulty == .medium || $0.difficulty == .easy }
                .sorted { $0.dueDate < $1.dueDate }
        case "🔴": // Not focused
            // Only show easy tasks
            return tasks.filter { $0.difficulty == .easy }
                .sorted { $0.dueDate < $1.dueDate }
        default:
            return tasks.sorted { $0.dueDate < $1.dueDate }
        }
    }
    
    /// Get suggested exercises based on mood
    static func getSuggestedExercises(for mood: String) -> [FocusExercise] {
        switch mood {
        case "🔴": // Not focused
            return [
                FocusExercise(title: "Try a 5-minute breathing exercise", duration: "5 min", icon: "wind"),
                FocusExercise(title: "Take a short walk outside", duration: "10 min", icon: "figure.walk"),
                FocusExercise(title: "Do 2 minutes of stretching", duration: "2 min", icon: "figure.flexibility"),
                FocusExercise(title: "Listen to calming music", duration: "5 min", icon: "music.note")
            ]
        case "🟡": // Moderate
            return [
                FocusExercise(title: "Start with easier tasks to build momentum", duration: "15 min", icon: "arrow.up.circle"),
                FocusExercise(title: "Use the Pomodoro timer", duration: "25 min", icon: "timer"),
                FocusExercise(title: "Take a 5-minute break", duration: "5 min", icon: "pause.circle")
            ]
        case "🟢": // Very focused
            return [
                FocusExercise(title: "Tackle your hardest tasks now", duration: "50 min", icon: "bolt.fill"),
                FocusExercise(title: "Extended study session", duration: "50 min", icon: "book.fill"),
                FocusExercise(title: "Create new study materials", duration: "30 min", icon: "plus.square.fill")
            ]
        default:
            return []
        }
    }
    
    /// Get mood description for display
    static func getMoodDescription(for mood: String) -> String {
        switch mood {
        case "🟢":
            return "Very Focused"
        case "🟡":
            return "Moderately Focused"
        case "🔴":
            return "Not Focused"
        default:
            return "Unknown"
        }
    }
    
    /// Get recommendation message based on mood
    static func getRecommendationMessage(for mood: String, taskCount: Int) -> String {
        switch mood {
        case "🟢":
            return "You're feeling great! Here are your harder tasks to tackle:"
        case "🟡":
            return "Let's start with medium-difficulty tasks:"
        case "🔴":
            if taskCount == 0 {
                return "No easy tasks available right now. Try one of these exercises to boost your focus:"
            }
            return "Let's keep it simple with easier tasks:"
        default:
            return "Here are your tasks:"
        }
    }
}
