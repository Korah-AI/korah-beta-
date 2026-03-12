import Foundation
import SwiftUI

@MainActor
@Observable
final class HomeDataManager {
    static let shared = HomeDataManager()
    
    var tasks: [StudyTask] = []

    /// Derived from `FirestoreStudyService.shared`; automatically reactive via `@Observable`.
    var recentStudyItems: [RecentStudyItem] {
        let studyService = FirestoreStudyService.shared
        let flashcardsItems = studyService.flashcardSets.map {
            RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.flashcardsKind, createdAt: $0.createdAt)
        }
        let guideItems = studyService.studyGuides.map {
            RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.studyGuideKind, createdAt: $0.createdAt)
        }
        let testItems = studyService.practiceTests.map {
            RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.practiceTestKind, createdAt: $0.createdAt)
        }
        return (flashcardsItems + guideItems + testItems).sorted { $0.createdAt > $1.createdAt }
    }
    
    private init() {
        loadTasks()
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "SavedTasks"),
           let savedTasks = try? JSONDecoder().decode([StudyTask].self, from: data) {
            tasks = savedTasks
        }
    }
    
    func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "SavedTasks")
        }
    }
    
    func addTask(_ task: StudyTask) {
        tasks.append(task)
        saveTasks()
    }
    
    func updateTask(_ task: StudyTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func deleteTask(_ task: StudyTask) {
        // Cancel notifications for the deleted task
        NotificationManager.shared.cancelTaskNotifications(for: task.id)
        
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func loadRecentStudyItems() {
        // No-op: recentStudyItems is now a computed property backed by FirestoreStudyService.shared.
    }
    
    func refreshAll() {
        loadTasks()
    }
}
