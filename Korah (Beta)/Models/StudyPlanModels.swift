import Foundation

// MARK: - Study Plan (shared with web)
// Firestore: users/{uid}/studyPlans/current — a single active plan per user.
// The web app mirrors this exact schema, so every field stays a JSON-friendly
// primitive (ISO date strings, not Timestamps).

/// Short, non-overwhelming AI feedback shown above the calendar.
struct StudyPlanFeedback: Codable, Equatable {
    var headline: String = ""
    var priorities: [String] = []
    var weeklyFocus: String = ""
}

/// One scheduled study block.
struct StudyPlanSession: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var date: String            // "yyyy-MM-dd"
    var start: String           // "HH:mm" (24h)
    var durationMin: Int
    var subject: String         // "math" | "english"
    var skillName: String       // display name, e.g. "Linear functions"
    var activity: String        // one line, e.g. "Practice set: linear equations in context"
    var completed: Bool = false

    var startDate: Date? {
        StudyPlanDates.dateTime(date: date, time: start)
    }

    var endTimeLabel: String {
        guard let start = startDate else { return "" }
        let end = start.addingTimeInterval(TimeInterval(durationMin * 60))
        return StudyPlanDates.timeLabel(end)
    }

    var startTimeLabel: String {
        guard let start = startDate else { return "" }
        return StudyPlanDates.timeLabel(start)
    }
}

/// The active study plan document.
struct StudyPlan: Codable, Equatable {
    var testDate: String        // "yyyy-MM-dd"
    var studyDays: [String]     // ["mon", "wed", "sat"]
    var hoursPerWeek: Int
    var source: String          // "sat" | "practice" | "self"
    var feedback: StudyPlanFeedback = StudyPlanFeedback()
    var sessions: [StudyPlanSession] = []
    var createdAt: String?
    var updatedAt: String?

    /// Sessions keyed by their "yyyy-MM-dd" date for calendar lookup.
    var sessionsByDate: [String: [StudyPlanSession]] {
        Dictionary(grouping: sessions, by: \.date)
            .mapValues { $0.sorted { $0.start < $1.start } }
    }
}

// MARK: - Wizard intake (not persisted; feeds the AI prompt)

struct StudyPlanIntake {
    var source: String = ""             // "sat" | "practice" | "self"
    var mathScore: Int?
    var englishScore: Int?
    /// Domain code → confidence 1 (shaky) ... 3 (strong). Only for "self".
    var confidence: [String: Int] = [:]
    /// Free text: the specific feedback the student wants. Only for "self".
    var focusRequest: String = ""
    var testDate: Date = Date()
    var studyDays: [String] = []        // ["mon", ...]
    var hoursPerWeek: Int = 6
}

// MARK: - Date helpers

enum StudyPlanDates {
    /// Weekday keys in the schema, Monday-first (matches the calendar grid).
    static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    static let dayLabels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func date(from dayString: String) -> Date? {
        dayFormatter.date(from: dayString)
    }

    static func dateTime(date: String, time: String) -> Date? {
        guard let day = Self.date(from: date) else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return day }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "mon" ... "sun" for a Date (Monday-first, locale independent).
    static func dayKey(_ date: Date) -> String {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday
        let weekday = Calendar.current.component(.weekday, from: date)
        return dayKeys[(weekday + 5) % 7]
    }
}
