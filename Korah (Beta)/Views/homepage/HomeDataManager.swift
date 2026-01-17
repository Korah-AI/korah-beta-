import Foundation
import SwiftUI
import Combine

class HomeDataManager: ObservableObject {
    static let shared = HomeDataManager()
    
    @Published var tasks: [Task] = []
    @Published var recentStudyItems: [RecentStudyItem] = []
    
    private init() {
        loadTasks()
        loadRecentStudyItems()
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func userDefaultsDidChange() {
        DispatchQueue.main.async {
            self.loadTasks()
            self.loadRecentStudyItems()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "SavedTasks"),
           let savedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = savedTasks
        }
    }
    
    func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "SavedTasks")
        }
    }
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
    
    func deleteTask(_ task: Task) {
        // Cancel notifications for the deleted task
        NotificationManager.shared.cancelTaskNotifications(for: task.id)
        
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func loadRecentStudyItems() {
        var allItems: [RecentStudyItem] = []
        let decoder = JSONDecoder()
        
        if let flashcardData = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let flashcardSets = try? decoder.decode([FlashcardSet].self, from: flashcardData) {
            let flashcardsItems = flashcardSets.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.flashcardsKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: flashcardsItems)
        }
        
        if let guidesData = UserDefaults.standard.data(forKey: "StudyGuides"),
           let studyGuides = try? decoder.decode([StudyGuide].self, from: guidesData) {
            let guideItems = studyGuides.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.studyGuideKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: guideItems)
        }
        
        if let testsData = UserDefaults.standard.data(forKey: "PracticeTests"),
           let practiceTests = try? decoder.decode([PracticeTest].self, from: testsData) {
            let testItems = practiceTests.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.practiceTestKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: testItems)
        }
        
        recentStudyItems = allItems.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    func refreshAll() {
        loadTasks()
        loadRecentStudyItems()
    }
}
