import Foundation
import UserNotifications
import SwiftUI

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    var notificationPermissionGranted = false

    /// How many days ahead the daily reminders are written out. iOS only keeps
    /// 64 pending requests, and study plan plus task reminders share that
    /// budget, so a week at a time is plenty. Every app open rewrites it.
    private let dailyHorizonDays = 7

    /// Identifier prefixes, so each family can be cleared without touching the
    /// others when we reschedule.
    private enum Prefix {
        static let daily = "sat_daily_"
        static let plan = "sat_plan_"
        static let comeback = "sat_comeback"
        static let streak = "streak_reminder"
    }

    /// Last time a "come back and finish the day" reminder was scheduled.
    /// Used to keep that nudge to once per 12 hours.
    private var lastComebackScheduledAt: Date? {
        get {
            let stamp = UserDefaults.standard.double(forKey: "LastComebackReminderAt")
            return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0,
                                      forKey: "LastComebackReminderAt")
        }
    }

    private init() {}

    // Request notification permissions
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
                completion(granted)

                if granted {
                    self.refreshSchedule()
                }
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

    /// Rewrite everything that depends on today's date. Safe to call on every
    /// app open and every scene activation.
    func refreshSchedule() {
        scheduleDailyNotifications()
        scheduleComebackReminder()
        scheduleStudyPlanNotifications(for: StudyPlanService.shared.plan)
    }

    // MARK: - Daily reminders (two per day, rotating)

    /// Two SAT reminders a day, one in the morning and one in the evening,
    /// each pulled from its own pool by day index so the same line never lands
    /// two days running. Written out one date at a time (rather than a
    /// repeating trigger) so the copy can rotate and the countdown can count.
    ///
    /// Identifiers are deterministic (`sat_daily_am_3`), so every refresh
    /// overwrites the whole window in place. Nothing needs clearing first.
    func scheduleDailyNotifications() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        for offset in 0..<dailyHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let index = dayIndex(for: day)

            let morning = morningCopy(for: day, index: index)
            schedule(morning, on: day, hour: 8, minute: 30,
                     identifier: "\(Prefix.daily)am_\(offset)", after: now)

            let evening = SATCopy.evening[index % SATCopy.evening.count]
            schedule(evening, on: day, hour: 19, minute: 30,
                     identifier: "\(Prefix.daily)pm_\(offset)", after: now)
        }
    }

    /// The morning slot switches to a countdown once the next official SAT is
    /// close enough for the number to mean something. Every third day, so the
    /// countdown feels like a heads up rather than a drumbeat.
    private func morningCopy(for day: Date, index: Int) -> SATCopy.Line {
        if let exam = SATExamDates.next {
            let calendar = Calendar.current
            let daysAway = calendar.dateComponents([.day],
                                                   from: calendar.startOfDay(for: day),
                                                   to: calendar.startOfDay(for: exam)).day ?? 0
            if daysAway >= 0 && (daysAway <= 7 || index % 3 == 0) {
                return SATCopy.countdown(daysAway: daysAway, index: index)
            }
        }
        // Offset so the morning and evening pools don't march in lockstep.
        return SATCopy.morning[(index + 3) % SATCopy.morning.count]
    }

    // MARK: - Come back and finish the day

    /// Fired a few hours after the student opens the app: they studied once
    /// today, this asks them to close the day out. Capped at one per 12 hours.
    func scheduleComebackReminder() {
        let now = Date()
        if let last = lastComebackScheduledAt, now.timeIntervalSince(last) < 12 * 3600 {
            return
        }

        let calendar = Calendar.current
        let fireDate = now.addingTimeInterval(4 * 3600)
        let hour = calendar.component(.hour, from: fireDate)

        // Nobody wants a study nudge at 2am. If the four hour mark lands in the
        // quiet window we skip it and let the next open earn one.
        guard hour >= 9 && hour < 22 else { return }

        let line = SATCopy.comeback[dayIndex(for: now) % SATCopy.comeback.count]

        let content = UNMutableNotificationContent()
        content.title = line.title
        content.body = line.body
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: Prefix.comeback, content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Prefix.comeback])
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling comeback reminder: \(error.localizedDescription)")
            }
        }

        lastComebackScheduledAt = now
    }

    // MARK: - Study plan reminders

    /// One reminder per scheduled study day, naming the skill the plan picked
    /// for that day. The wrapper copy rotates so a five day a week plan doesn't
    /// send the same sentence five times.
    func scheduleStudyPlanNotifications(for plan: StudyPlan?) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let sessionsByDate = plan?.sessionsByDate ?? [:]

        var requests: [UNNotificationRequest] = []

        for offset in 0..<dailyHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let key = StudyPlanDates.dayString(day)
            // The first thing still outstanding that day is what we announce.
            guard let session = sessionsByDate[key]?.first(where: { !$0.completed }),
                  let start = session.startDate,
                  let fireDate = calendar.date(byAdding: .minute, value: -15, to: start),
                  fireDate > now else { continue }

            let line = SATCopy.planLine(index: dayIndex(for: day), session: session)

            let content = UNMutableNotificationContent()
            content.title = line.title
            content.body = line.body
            content.sound = .default
            content.badge = 1

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            requests.append(UNNotificationRequest(identifier: "\(Prefix.plan)\(key)",
                                                  content: content,
                                                  trigger: trigger))
        }

        // Plan identifiers are date keyed, so days that dropped off the plan
        // have to be cleared. Clear first, then add, so the removal can't race
        // ahead and delete what we just queued.
        let keep = Set(requests.map(\.identifier))
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier)
                .filter { $0.hasPrefix(Prefix.plan) && !keep.contains($0) }
            if !stale.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stale)
            }
            for request in requests {
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error scheduling study plan notification: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Days since the epoch, used as the rotation cursor so the copy advances
    /// by one every calendar day and stays stable within a day.
    private func dayIndex(for date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: date)
        return Int(start.timeIntervalSince1970 / 86_400)
    }

    /// Schedule one line at a wall clock time on a specific day.
    private func schedule(_ line: SATCopy.Line, on day: Date, hour: Int, minute: Int,
                          identifier: String, after now: Date) {
        let calendar = Calendar.current
        guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
              fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = line.title
        content.body = line.body
        content.sound = .default
        content.badge = 1

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    // Schedule a streak reminder notification (for when user hasn't opened app in >18 hours)
    func scheduleStreakReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Your SAT streak is on the line 🔥"
        content.body = "You haven't practiced today. One short set keeps it alive."
        content.sound = .default
        content.badge = 1

        // Trigger after 18 hours of inactivity
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 18 * 3600, repeats: false)

        let request = UNNotificationRequest(identifier: Prefix.streak, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling streak reminder: \(error.localizedDescription)")
            }
        }
    }

    // Cancel the streak reminder when user opens the app
    func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Prefix.streak])
    }

    // MARK: - Task Notification Methods

    /// Schedule notifications for a task (1 day before and 1 hour before)
    func scheduleTaskNotifications(for task: StudyTask) {
        // Cancel existing notifications for this task
        cancelTaskNotifications(for: task.id)

        let now = Date()
        let taskDueDate = task.dueDate

        // Schedule 1 day before notification
        let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: taskDueDate)
        if let oneDayBefore = oneDayBefore, oneDayBefore > now {
            scheduleTaskNotification(
                taskId: task.id,
                title: "Due tomorrow 📅",
                body: "\(task.title) is due tomorrow. Get it done and keep tomorrow free.",
                date: oneDayBefore,
                identifier: "task_\(task.id.uuidString)_1day"
            )
        }

        // Schedule 1 hour before notification
        let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: taskDueDate)
        if let oneHourBefore = oneHourBefore, oneHourBefore > now {
            scheduleTaskNotification(
                taskId: task.id,
                title: "One hour left ⏰",
                body: "\(task.title) is due in an hour.",
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
    func rescheduleAllTaskNotifications(tasks: [StudyTask]) {
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

// MARK: - Copy

/// Every notification line the app can send, in one place. Voice rules live in
/// COPY_GUIDE.md: sentence case, contractions, no em dashes. Notifications are
/// the one surface that leans on emoji, one per title, to earn a glance on the
/// lock screen.
enum SATCopy {

    struct Line {
        let title: String
        let body: String
    }

    /// Morning slot, 8:30am.
    static let morning: [Line] = [
        Line(title: "Your dream score starts here ✨",
             body: "Lock in and study with Korah!"),
        Line(title: "Good morning 🌅",
             body: "A few SAT questions now and the whole day feels ahead of you."),
        Line(title: "Big score energy today 💫",
             body: "Open Korah and get a quick round in."),
        Line(title: "Ready to level up? 📈",
             body: "One short SAT session is all it takes to move the needle."),
        Line(title: "Your future self says thanks 🙌",
             body: "Start the day with a little SAT practice."),
        Line(title: "Let's go get those points 🎯",
             body: "Quick practice round, right now. You've got this."),
        Line(title: "Rise and grind ☀️",
             body: "Ten minutes of SAT prep before the day gets loud."),
        Line(title: "Brain warm up 🧠",
             body: "A few questions to get you sharp. Let's go!"),
        Line(title: "Streak check 🔥",
             body: "Keep it alive with one quick session."),
        Line(title: "Score goals 🏆",
             body: "Every session gets you closer. Come study with Korah.")
    ]

    /// Evening slot, 7:30pm.
    static let evening: [Line] = [
        Line(title: "Lock in tonight 🔒",
             body: "One short SAT session and today counts."),
        Line(title: "Don't let the day end at zero 🌙",
             body: "A quick round of practice is all you need."),
        Line(title: "Your dream score is waiting ⭐",
             body: "Come get a session in before bed."),
        Line(title: "Ten minutes, big payoff ⏳",
             body: "Squeeze in some SAT practice tonight."),
        Line(title: "Evening grind 🌆",
             body: "Study now, stress less later. Let's go!"),
        Line(title: "Keep the streak alive 🔥",
             body: "One session tonight and you're good."),
        Line(title: "Small wins stack up 📚",
             body: "Get a quick SAT round in before you wind down."),
        Line(title: "How's the score looking? 📊",
             body: "Check your progress and run a quick set."),
        Line(title: "End the day strong 💪",
             body: "A little SAT prep now beats cramming later."),
        Line(title: "Future you is watching 👀",
             body: "Come study with Korah for a few minutes.")
    ]

    /// Countdown copy for the morning slot, phrased the way a person would say
    /// it: months out early on, days once it's close.
    static func countdown(daysAway: Int, index: Int) -> Line {
        switch daysAway {
        case 0:
            return Line(title: "It's SAT day 🎓",
                        body: "You put in the work. Go get your score!")
        case 1:
            return Line(title: "The SAT is tomorrow 🌟",
                        body: "Light review, early night. You're ready for this.")
        default:
            let bodies = [
                "Come back and study for your dream score!",
                "Every session between now and then counts.",
                "Lock in with Korah and make these days count.",
                "Still plenty of time to move your score. Start today!"
            ]
            return Line(title: "The SAT is in \(countdownPhrase(daysAway)) 📅",
                        body: bodies[index % bodies.count])
        }
    }

    /// "5 days", "3 weeks", "a month", "2 months".
    private static func countdownPhrase(_ days: Int) -> String {
        switch days {
        case ..<14:
            return "\(days) days"
        case ..<46:
            let weeks = Int((Double(days) / 7).rounded())
            return "\(weeks) weeks"
        default:
            let months = Int((Double(days) / 30).rounded())
            return months <= 1 ? "a month" : "\(months) months"
        }
    }

    /// The "you studied earlier, come finish the day" nudge.
    static let comeback: [Line] = [
        Line(title: "Come back and finish the day 💪",
             body: "You studied earlier. One more round for your dream score!"),
        Line(title: "Round two? 🔁",
             body: "You're already warmed up. Come lock in with Korah."),
        Line(title: "Don't stop now ✨",
             body: "A second session today is how scores really move."),
        Line(title: "Your dream score is calling ⭐",
             body: "You started strong. Come finish the day!"),
        Line(title: "One more round? 🎯",
             body: "Quick session, then you're done for the day."),
        Line(title: "Still got a few minutes? ⏳",
             body: "Come back to Korah and close out the day strong.")
    ]

    /// Study plan day reminders. Light on specifics: the plan itself has the
    /// detail, this is just the tap on the shoulder.
    static func planLine(index: Int, session: StudyPlanSession) -> Line {
        let skill = session.skillName
        let subject = subjectLabel(session.subject)
        let minutes = session.durationMin

        let lines = [
            Line(title: "Study time 📅",
                 body: "Today's session is on your plan. Let's lock in!"),
            Line(title: "Your plan says now ⏰",
                 body: "\(skill) is up today. Quick session, big payoff."),
            Line(title: "Time to study ✨",
                 body: "You scheduled today. Come get it in with Korah."),
            Line(title: "Today's focus: \(subject) 📚",
                 body: "Your plan is ready when you are."),
            Line(title: "Don't skip today 💪",
                 body: "A session is waiting, and your dream score needs it."),
            Line(title: "Study block starting 🔔",
                 body: "\(minutes) minutes on \(subject), then you're free."),
            Line(title: "Stay on plan 📈",
                 body: "Today's session is ready. Let's keep the momentum!")
        ]
        return lines[index % lines.count]
    }

    private static func subjectLabel(_ subject: String) -> String {
        subject.lowercased() == "math" ? "Math" : "Reading and Writing"
    }
}
