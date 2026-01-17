import Foundation
import Combine
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()

    static let shared = NotificationManager()
    
    @Published var notificationPermissionGranted = false
    
    private init() {}
    
    // Request notification permissions
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
                completion(granted)
            }
            
            if granted {
                self.scheduleCreativeNotifications()
            }
        }
    }
    
    // Check current notification permission status
    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized
                self.notificationPermissionGranted = granted
                completion(granted)
            }
        }
    }
    
    // Schedule all creative notifications
    func scheduleCreativeNotifications() {
        // Remove all pending notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Pick one random notification for each time period
        scheduleMorningNotifications()
        scheduleAfternoonNotifications()
        scheduleEveningNotifications()
    }
    
    // MARK: - Morning Notifications (8 AM - 11 AM)
    
    private func scheduleMorningNotifications() {
        let morningNotifications = [
            NotificationContent(
                title: "Good morning! ☀️",
                body: "Start your day strong—review your flashcards while your mind is fresh!",
                hour: 8,
                minute: 0
            ),
            NotificationContent(
                title: "Rise and shine! ✨",
                body: "Your brain is at peak performance in the morning. Let's study!",
                hour: 8,
                minute: 30
            ),
            NotificationContent(
                title: "Coffee break = Study break ☕",
                body: "Pair your morning brew with a quick practice test!",
                hour: 9,
                minute: 0
            ),
            NotificationContent(
                title: "Your streak is waiting! 🔥",
                body: "Don't break your study streak—check in and keep it going!",
                hour: 9,
                minute: 30
            ),
            NotificationContent(
                title: "Knowledge time! 🧠",
                body: "Tackle that study guide you've been saving. You got this!",
                hour: 10,
                minute: 0
            ),
            NotificationContent(
                title: "Quick wins incoming! 🎯",
                body: "Spend 5 minutes on flashcards and feel accomplished!",
                hour: 10,
                minute: 30
            )
        ]
        
        // Pick one random notification from the morning options
        if let randomNotification = morningNotifications.randomElement() {
            scheduleNotification(randomNotification, identifier: "morning")
        }
    }
    
    // MARK: - Afternoon Notifications (2 PM - 5 PM)
    
    private func scheduleAfternoonNotifications() {
        let afternoonNotifications = [
            NotificationContent(
                title: "Afternoon boost! 💪",
                body: "Beat the afternoon slump with some active learning. Let's go!",
                hour: 14,
                minute: 0
            ),
            NotificationContent(
                title: "Study snack time! 🍎",
                body: "Grab a snack and review your notes—your brain needs fuel!",
                hour: 14,
                minute: 30
            ),
            NotificationContent(
                title: "You're halfway there! 🌟",
                body: "The day's not over—make it count with a quick study session!",
                hour: 15,
                minute: 0
            ),
            NotificationContent(
                title: "Brain break alert! 🎨",
                body: "Take 10 minutes to scan and create new study materials!",
                hour: 15,
                minute: 30
            ),
            NotificationContent(
                title: "Practice makes progress! 📈",
                body: "Challenge yourself with a practice test right now!",
                hour: 16,
                minute: 0
            ),
            NotificationContent(
                title: "Golden hour learning! ✨",
                body: "This is your time to shine—dive into your study guides!",
                hour: 16,
                minute: 30
            )
        ]
        
        // Pick one random notification from the afternoon options
        if let randomNotification = afternoonNotifications.randomElement() {
            scheduleNotification(randomNotification, identifier: "afternoon")
        }
    }
    
    // MARK: - Evening Notifications (7 PM - 9 PM)
    
    private func scheduleEveningNotifications() {
        let eveningNotifications = [
            NotificationContent(
                title: "Evening wind-down 🌙",
                body: "Review today's lessons before you relax—solidify that knowledge!",
                hour: 19,
                minute: 0
            ),
            NotificationContent(
                title: "Did you study today? 🤔",
                body: "A few minutes now can make tomorrow so much easier!",
                hour: 19,
                minute: 30
            ),
            NotificationContent(
                title: "Bedtime prep! 📚",
                body: "End your day on a high note with a quick flashcard review!",
                hour: 20,
                minute: 0
            ),
            NotificationContent(
                title: "Last call for learning! ⏰",
                body: "Don't let the day end without checking your streak!",
                hour: 20,
                minute: 30
            ),
            NotificationContent(
                title: "Sweet dreams start here 😴",
                body: "Review before bed for better retention. Science says so!",
                hour: 21,
                minute: 0
            )
        ]
        
        // Pick one random notification from the evening options
        if let randomNotification = eveningNotifications.randomElement() {
            scheduleNotification(randomNotification, identifier: "evening")
        }
    }
    
    // MARK: - Helper Methods
    
    // Schedule a single notification
    private func scheduleNotification(_ notification: NotificationContent, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.badge = 1
        
        // Create date components for the notification
        var dateComponents = DateComponents()
        dateComponents.hour = notification.hour
        dateComponents.minute = notification.minute
        
        // Create a trigger that repeats daily
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request with unique identifier
        let requestIdentifier = "\(identifier)_\(notification.hour)_\(notification.minute)"
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedule a streak reminder notification (for when user hasn't opened app in >18 hours)
    func scheduleStreakReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Don't lose your streak! 🔥"
        content.body = "You haven't checked in today. Keep your learning momentum going!"
        content.sound = .default
        content.badge = 1
        
        // Trigger after 18 hours of inactivity
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 18 * 3600, repeats: false)
        
        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling streak reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // Cancel the streak reminder when user opens the app
    func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_reminder"])
    }
    
    // MARK: - Task Notification Methods
    
    /// Schedule notifications for a task (1 day before and 1 hour before)
    func scheduleTaskNotifications(for task: Task) {
        // Cancel existing notifications for this task
        cancelTaskNotifications(for: task.id)
        
        let now = Date()
        let taskDueDate = task.dueDate
        
        // Schedule 1 day before notification
        let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: taskDueDate)
        if let oneDayBefore = oneDayBefore, oneDayBefore > now {
            scheduleTaskNotification(
                taskId: task.id,
                title: "Task Due Tomorrow! 📅",
                body: "\(task.title) is due tomorrow. Time to wrap it up!",
                date: oneDayBefore,
                identifier: "task_\(task.id.uuidString)_1day"
            )
        }
        
        // Schedule 1 hour before notification
        let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: taskDueDate)
        if let oneHourBefore = oneHourBefore, oneHourBefore > now {
            scheduleTaskNotification(
                taskId: task.id,
                title: "Task Due Soon! ⏰",
                body: "\(task.title) is due in 1 hour. Last chance!",
                date: oneHourBefore,
                identifier: "task_\(task.id.uuidString)_1hour"
            )
        }
    }
    
    /// Schedule a single task notification
    private func scheduleTaskNotification(taskId: UUID, title: String, body: String, date: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.userInfo = ["taskId": taskId.uuidString]
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling task notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Cancel all notifications for a specific task
    func cancelTaskNotifications(for taskId: UUID) {
        let identifiers = [
            "task_\(taskId.uuidString)_1day",
            "task_\(taskId.uuidString)_1hour"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// Reschedule notifications for all tasks
    func rescheduleAllTaskNotifications(tasks: [Task]) {
        // Cancel all existing task notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let taskNotificationIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("task_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: taskNotificationIds)
            
            // Schedule notifications for all tasks
            for task in tasks {
                self.scheduleTaskNotifications(for: task)
            }
        }
    }
    
    // Get count of pending notifications (for debugging)
    func getPendingNotificationCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests.count)
        }
    }
}

// MARK: - Supporting Structures

struct NotificationContent {
    let title: String
    let body: String
    let hour: Int
    let minute: Int
}

