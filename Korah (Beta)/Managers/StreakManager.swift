import Foundation
import SwiftUI

@MainActor
@Observable
final class StreakManager {
    static let shared = StreakManager()
    
    var currentStreak: Int = 0
    var lastAppOpenDate: Date?
    
    private let lastAppOpenKey = "LastAppOpenDate"
    private let currentStreakKey = "CurrentStreak"
    private let streakDatesKey = "StreakDates"
    
    private init() {
        loadStreakData()
    }
    
    // Load saved streak data
    private func loadStreakData() {
        if let lastOpenTimestamp = UserDefaults.standard.object(forKey: lastAppOpenKey) as? Double {
            lastAppOpenDate = Date(timeIntervalSince1970: lastOpenTimestamp)
        }
        currentStreak = UserDefaults.standard.integer(forKey: currentStreakKey)
    }
    
    // Record that the user opened the app
    func recordAppOpen() {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        // Get the last app open date (start of day)
        if let lastOpen = lastAppOpenDate {
            let lastOpenDay = calendar.startOfDay(for: lastOpen)
            
            // Calculate the difference in days
            let daysDifference = calendar.dateComponents([.day], from: lastOpenDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                // Same day - don't change streak
                return
            } else if daysDifference == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
                saveStreakDate(today)
            } else if daysDifference > 1 {
                // Missed days - reset streak to 1
                currentStreak = 1
                clearStreakDates()
                saveStreakDate(today)
            }
        } else {
            // First time opening the app
            currentStreak = 1
            saveStreakDate(today)
        }
        
        // Save the current timestamp
        lastAppOpenDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastAppOpenKey)
        UserDefaults.standard.set(currentStreak, forKey: currentStreakKey)
    }
    
    // Check if streak should be reset (called on app open)
    func checkAndUpdateStreak() {
        guard let lastOpen = lastAppOpenDate else {
            // First time - initialize streak
            recordAppOpen()
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let lastOpenDay = calendar.startOfDay(for: lastOpen)
        
        let daysDifference = calendar.dateComponents([.day], from: lastOpenDay, to: today).day ?? 0
        
        // If more than 1 day has passed, the streak should be reset
        if daysDifference > 1 {
            currentStreak = 0
            UserDefaults.standard.set(0, forKey: currentStreakKey)
            clearStreakDates()
        }
        
        // Now record the app open
        recordAppOpen()
    }
    
    // Get the current streak count
    func getCurrentStreak() -> Int {
        // Double-check if streak should be reset before returning
        if let lastOpen = lastAppOpenDate {
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            let lastOpenDay = calendar.startOfDay(for: lastOpen)
            let daysDifference = calendar.dateComponents([.day], from: lastOpenDay, to: today).day ?? 0
            
            // If more than 1 day has passed since last open, streak is 0
            if daysDifference > 1 {
                return 0
            }
        }
        
        return currentStreak
    }
    
    // Helper to save streak date
    private func saveStreakDate(_ date: Date) {
        var dates = getStreakDates()
        if !dates.contains(date) {
            dates.append(date)
            let timestamps = dates.map { $0.timeIntervalSince1970 }
            UserDefaults.standard.set(timestamps, forKey: streakDatesKey)
        }
    }
    
    // Helper to get streak dates
    private func getStreakDates() -> [Date] {
        if let timestamps = UserDefaults.standard.array(forKey: streakDatesKey) as? [Double] {
            return timestamps.map { Date(timeIntervalSince1970: $0) }
        }
        return []
    }
    
    // Helper to clear streak dates
    private func clearStreakDates() {
        UserDefaults.standard.removeObject(forKey: streakDatesKey)
    }
    
    // Get hours since last app open
    func hoursSinceLastOpen() -> Double? {
        guard let lastOpen = lastAppOpenDate else { return nil }
        return Date().timeIntervalSince(lastOpen) / 3600
    }
}

