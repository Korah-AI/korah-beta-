import Foundation

struct FocusExercise: Identifiable {
    let id = UUID()
    let title: String
    let duration: String
    let icon: String
}

enum MoodHelpers {
    /// Check if a task is recommended based on current mood
    static func isTaskRecommended(task: StudyTask, for mood: String) -> Bool {
        switch mood {
        case "🟢": // Very focused
            // All tasks are good, but harder tasks are better
            return true
        case "🟡": // Moderately focused
            // Recommend medium and easy tasks
            return task.difficulty == .medium || task.difficulty == .easy
        case "🔴": // Not focused
            // Only recommend easy tasks
            return task.difficulty == .easy
        default:
            return true
        }
    }
    
    /// Get tasks sorted with recommended tasks first based on current mood
    static func getSortedTasks(for mood: String, tasks: [StudyTask]) -> [StudyTask] {
        if mood.isEmpty {
            return tasks.sorted { $0.dueDate < $1.dueDate }
        }
        
        // Separate recommended and non-recommended tasks
        let recommended = tasks.filter { isTaskRecommended(task: $0, for: mood) }
        let others = tasks.filter { !isTaskRecommended(task: $0, for: mood) }
        
        // Sort each group
        let sortedRecommended: [StudyTask]
        switch mood {
        case "🟢": // Very focused - prioritize harder tasks
            sortedRecommended = recommended.sorted { 
                if $0.difficulty != $1.difficulty {
                    return $0.difficulty.rawValue > $1.difficulty.rawValue
                }
                return $0.dueDate < $1.dueDate
            }
        default: // Other moods - sort by due date
            sortedRecommended = recommended.sorted { $0.dueDate < $1.dueDate }
        }
        
        let sortedOthers = others.sorted { $0.dueDate < $1.dueDate }
        
        // Return recommended tasks first, then others
        return sortedRecommended + sortedOthers
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
    static func getRecommendationMessage(for mood: String, recommendedCount: Int, totalCount: Int) -> String {
        switch mood {
        case "🟢":
            return "You're feeling great! Tackle your tasks starting with the harder ones:"
        case "🟡":
            if recommendedCount > 0 {
                return "\(recommendedCount) recommended task\(recommendedCount == 1 ? "" : "s") for your current focus level:"
            }
            return "Start with easier tasks to build momentum:"
        case "🔴":
            if recommendedCount == 0 {
                return "No easy tasks right now. Consider these exercises to boost your focus:"
            }
            return "\(recommendedCount) easy task\(recommendedCount == 1 ? "" : "s") recommended for you:"
        default:
            return "Here are your tasks:"
        }
    }
}
