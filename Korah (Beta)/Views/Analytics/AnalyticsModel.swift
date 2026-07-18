import Foundation
import SwiftUI

// MARK: - Analytics tab model
// One fetch of the full satAttempts log (plus profile/bookmarks), then every
// card on the Analytics tab is derived in memory. Switching the time range
// never refetches — it just re-filters the parsed attempts.

// MARK: - Time range

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case week = "7 days"
    case month = "30 days"
    case all = "All time"

    var id: String { rawValue }

    /// nil = no cutoff
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

// MARK: - Parsed attempt

/// An attempt with its ISO timestamp parsed once, so derivations never touch
/// the formatter again.
struct AnalyticsAttempt: Identifiable {
    let id: String
    let questionId: String
    let date: Date
    let correct: Bool
    let difficulty: String   // "E" | "M" | "H"
    let section: String      // "english" | "math"
    let domain: String
    let skillCd: String
    let timeSpent: Int       // seconds
    let mode: String         // "player" | "rush" | "" (legacy → player)
    let xp: Int
}

// MARK: - Derived shapes

/// One stacked bar in the activity trend: a week's attempts split by outcome
/// and difficulty (harder segments render darker, like the web report).
struct AnalyticsWeekBucket: Identifiable {
    let weekStart: Date
    /// Keyed [difficulty: count]
    var correct: [String: Int] = [:]
    var wrong: [String: Int] = [:]

    var id: Date { weekStart }
}

/// A skill ranked by how many points it is costing (weakness scoring mirrors
/// `SATAnalyticsService.suggestSkills`, computed over the filtered window).
struct AnalyticsCostingTopic: Identifiable {
    let skillCd: String
    let skillName: String
    let domain: String
    let section: String
    let attempts: Int
    let correct: Int
    let weakness: Double

    var id: String { skillCd }
    var accuracy: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
    var missRate: Double { attempts > 0 ? 1 - accuracy : 0 }
}

/// Domain-level accuracy with its skills, for the per-section topic cards.
struct AnalyticsDomainStat: Identifiable {
    let domain: String
    let section: String
    let attempts: Int
    let correct: Int
    let skills: [AnalyticsSkillStat]

    var id: String { "\(section)|\(domain)" }
    var accuracy: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
}

struct AnalyticsSkillStat: Identifiable {
    let skillCd: String
    let skillName: String
    let attempts: Int
    let correct: Int

    var id: String { skillCd }
    var accuracy: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
}

/// Per-difficulty time within a section ("Time per difficulty" card).
struct AnalyticsDifficultyTime: Identifiable {
    let difficulty: String   // "E" | "M" | "H"
    let attempts: Int
    let totalSeconds: Int

    var id: String { difficulty }
    var averageSeconds: Int { attempts > 0 ? totalSeconds / attempts : 0 }
}

/// The pacing quadrant: every timed attempt classified fast/slow (relative to
/// the median for its difficulty) × right/wrong.
struct AnalyticsPacing {
    var fastRight = 0
    var fastWrong = 0
    var slowRight = 0
    var slowWrong = 0

    var total: Int { fastRight + fastWrong + slowRight + slowWrong }

    /// The one-line read a tutor would give.
    var headline: String {
        guard total > 0 else { return "Answer timed questions to see your pacing." }
        let problems = [(fastWrong, "rushing"), (slowWrong, "stuck"), (slowRight, "slow")]
        let worst = problems.max { $0.0 < $1.0 }!
        let share = Double(worst.0) / Double(total)
        guard share >= 0.25 else { return "Balanced pacing. Keep it up." }
        switch worst.1 {
        case "rushing": return "You miss most when you answer fast. Slow down and re-read."
        case "stuck": return "Long, wrong answers are your biggest leak. Flag and move on."
        default: return "Accuracy is there. Now work on speed."
        }
    }
}

/// A skill that has gone stale (or was never touched).
struct AnalyticsNeglectedSkill: Identifiable {
    let skillCd: String
    let skillName: String
    let domain: String
    let section: String
    /// nil = never attempted
    let daysSinceSeen: Int?

    var id: String { skillCd }
}

// MARK: - Model

@MainActor
@Observable
final class SATAnalyticsModel {
    // Raw
    private(set) var profile: SATProfile?
    private(set) var bookmarks: [SATBookmark] = []
    /// Full parsed log, newest first.
    private(set) var allAttempts: [AnalyticsAttempt] = []
    private(set) var isLoading = false
    private(set) var hasLoadedOnce = false

    var range: AnalyticsRange = .all

    // MARK: Load

    func load() async {
        isLoading = true
        defer { isLoading = false; hasLoadedOnce = true }
        let service = SATAnalyticsService.shared
        async let profileTask = try? service.getProfile()
        async let attemptsTask = try? service.getAllAttempts()
        async let bookmarksTask = try? service.getBookmarks()

        profile = await profileTask
        bookmarks = (await bookmarksTask ?? []).sorted { $0.ts > $1.ts }
        allAttempts = (await attemptsTask ?? []).compactMap(Self.parse)
    }

    private static func parse(_ attempt: SATAttempt) -> AnalyticsAttempt? {
        guard let date = ISO8601DateFormatter.satShared.date(from: attempt.ts)
                ?? ISO8601DateFormatter().date(from: attempt.ts) else { return nil }
        let canonical = attempt.detailKey.isEmpty ? attempt.questionId : attempt.detailKey
        return AnalyticsAttempt(
            id: attempt.id, questionId: canonical, date: date,
            correct: attempt.correct,
            difficulty: ["E", "M", "H"].contains(attempt.difficulty) ? attempt.difficulty : "E",
            section: attempt.section, domain: attempt.domain,
            skillCd: attempt.skillCd, timeSpent: attempt.timeSpent,
            mode: attempt.mode ?? "", xp: attempt.xp)
    }

    // MARK: Range filter

    var filtered: [AnalyticsAttempt] {
        guard let days = range.days else { return allAttempts }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allAttempts.filter { $0.date >= cutoff }
    }

    // MARK: Header stats

    var attemptedCount: Int { filtered.count }
    var correctCount: Int { filtered.filter(\.correct).count }
    var wrongCount: Int { attemptedCount - correctCount }
    var accuracy: Double { attemptedCount > 0 ? Double(correctCount) / Double(attemptedCount) : 0 }
    var savedCount: Int { bookmarks.count }
    var streak: Int { StreakManager.shared.getCurrentStreak() }

    // MARK: Activity trend (weekly stacked bars)

    var weekBuckets: [AnalyticsWeekBucket] {
        let calendar = Calendar.current
        let attempts = filtered
        guard !attempts.isEmpty else { return [] }
        var map: [Date: AnalyticsWeekBucket] = [:]
        for attempt in attempts {
            let week = calendar.dateInterval(of: .weekOfYear, for: attempt.date)?.start
                ?? calendar.startOfDay(for: attempt.date)
            var bucket = map[week] ?? AnalyticsWeekBucket(weekStart: week)
            if attempt.correct {
                bucket.correct[attempt.difficulty, default: 0] += 1
            } else {
                bucket.wrong[attempt.difficulty, default: 0] += 1
            }
            map[week] = bucket
        }
        // Fill empty weeks between first and last so gaps read as gaps.
        let sorted = map.keys.sorted()
        guard let first = sorted.first, let last = sorted.last else { return [] }
        var buckets: [AnalyticsWeekBucket] = []
        var cursor = first
        while cursor <= last {
            buckets.append(map[cursor] ?? AnalyticsWeekBucket(weekStart: cursor))
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? last.addingTimeInterval(1)
        }
        return buckets
    }

    // MARK: Study time splits (question-facing time only)

    var totalTimedSeconds: Int { filtered.reduce(0) { $0 + max(0, $1.timeSpent) } }

    var timeEnglish: Int { filtered.filter { $0.section == "english" }.reduce(0) { $0 + max(0, $1.timeSpent) } }
    var timeMath: Int { filtered.filter { $0.section == "math" }.reduce(0) { $0 + max(0, $1.timeSpent) } }

    var timeQuestions: Int { filtered.filter { $0.mode != "rush" }.reduce(0) { $0 + max(0, $1.timeSpent) } }
    var timeRush: Int { filtered.filter { $0.mode == "rush" }.reduce(0) { $0 + max(0, $1.timeSpent) } }

    /// Per-section E/M/H time rows for the pacing card.
    func difficultyTimes(section: String) -> [AnalyticsDifficultyTime] {
        let attempts = filtered.filter { $0.section == section && $0.timeSpent > 0 }
        return ["E", "M", "H"].map { diff in
            let subset = attempts.filter { $0.difficulty == diff }
            return AnalyticsDifficultyTime(
                difficulty: diff,
                attempts: subset.count,
                totalSeconds: subset.reduce(0) { $0 + $1.timeSpent })
        }
    }

    // MARK: Goal pace

    var pointsToGoal: Int? {
        guard let current = profile?.currentScore, let goal = profile?.goalScore else { return nil }
        return max(0, goal - current)
    }

    var daysUntilTest: Int? {
        guard let iso = profile?.testDate,
              let date = ISO8601DateFormatter.satShared.date(from: iso)
                ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        return max(0, days)
    }

    /// Average attempts per day over the last 14 days (all attempts, not range).
    var recentDailyPace: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recent = allAttempts.filter { $0.date >= cutoff }
        return Double(recent.count) / 14.0
    }

    /// Rough suggested questions/day from the score gap and calendar. A
    /// heuristic pace, not a promise — the card labels it as such.
    var suggestedDailyQuestions: Int? {
        guard let gap = pointsToGoal, gap > 0 else { return nil }
        let days = max(1, daysUntilTest ?? 60)
        let raw = Double(gap) / Double(days) * 1.5
        let clamped = min(60.0, max(8.0, raw))
        return Int((clamped / 5).rounded(.up)) * 5
    }

    // MARK: Momentum (this week vs last week, always trailing-7-day windows)

    struct Momentum {
        let attemptsThisWeek: Int
        let attemptsLastWeek: Int
        let accuracyThisWeek: Double?
        let accuracyLastWeek: Double?

        var volumeDelta: Int { attemptsThisWeek - attemptsLastWeek }
        var accuracyDelta: Double? {
            guard let now = accuracyThisWeek, let prev = accuracyLastWeek else { return nil }
            return now - prev
        }
    }

    var momentum: Momentum {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let thisWeek = allAttempts.filter { $0.date >= weekAgo }
        let lastWeek = allAttempts.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }
        func acc(_ list: [AnalyticsAttempt]) -> Double? {
            guard !list.isEmpty else { return nil }
            return Double(list.filter(\.correct).count) / Double(list.count)
        }
        return Momentum(attemptsThisWeek: thisWeek.count,
                        attemptsLastWeek: lastWeek.count,
                        accuracyThisWeek: acc(thisWeek),
                        accuracyLastWeek: acc(lastWeek))
    }

    // MARK: Topics costing the most points

    var costingTopics: [AnalyticsCostingTopic] {
        var bySkill: [String: (attempts: Int, correct: Int)] = [:]
        for attempt in filtered {
            var entry = bySkill[attempt.skillCd] ?? (0, 0)
            entry.attempts += 1
            if attempt.correct { entry.correct += 1 }
            bySkill[attempt.skillCd] = entry
        }
        var scored: [AnalyticsCostingTopic] = []
        for entry in SATCatalog.allSkills {
            guard let agg = bySkill[entry.skill.code], agg.attempts > 0 else { continue }
            let accuracy = Double(agg.correct) / Double(agg.attempts)
            let confidence = min(1.0, Double(agg.attempts) / 10.0)
            let weakness = (1 - accuracy) * confidence + 0.3 * (1 - confidence)
            scored.append(AnalyticsCostingTopic(
                skillCd: entry.skill.code, skillName: entry.skill.name,
                domain: entry.domain.name, section: entry.section.key,
                attempts: agg.attempts, correct: agg.correct, weakness: weakness))
        }
        scored.sort { $0.weakness > $1.weakness }
        return Array(scored.prefix(5))
    }

    // MARK: Accuracy by topic (per section)

    func domainStats(section: String) -> [AnalyticsDomainStat] {
        let sectionInfo = section == "math" ? SATCatalog.math : SATCatalog.english
        let attempts = filtered.filter { $0.section == section }
        guard !attempts.isEmpty else { return [] }
        var bySkill: [String: (attempts: Int, correct: Int)] = [:]
        for attempt in attempts {
            var entry = bySkill[attempt.skillCd] ?? (0, 0)
            entry.attempts += 1
            if attempt.correct { entry.correct += 1 }
            bySkill[attempt.skillCd] = entry
        }
        return sectionInfo.domains.compactMap { domain in
            let skills: [AnalyticsSkillStat] = domain.skills.compactMap { skill in
                guard let agg = bySkill[skill.code], agg.attempts > 0 else { return nil }
                return AnalyticsSkillStat(skillCd: skill.code, skillName: skill.name,
                                          attempts: agg.attempts, correct: agg.correct)
            }
            let attempts = skills.reduce(0) { $0 + $1.attempts }
            guard attempts > 0 else { return nil }
            return AnalyticsDomainStat(
                domain: domain.name, section: section,
                attempts: attempts,
                correct: skills.reduce(0) { $0 + $1.correct },
                skills: skills.sorted { $0.attempts > $1.attempts })
        }
    }

    // MARK: Pacing quadrant

    var pacing: AnalyticsPacing {
        let timed = filtered.filter { $0.timeSpent > 0 }
        var result = AnalyticsPacing()
        guard timed.count >= 4 else { return result }
        // Median per difficulty, so "fast" is relative to the question's own tier.
        var medians: [String: Int] = [:]
        for diff in ["E", "M", "H"] {
            let times = timed.filter { $0.difficulty == diff }.map(\.timeSpent).sorted()
            if !times.isEmpty { medians[diff] = times[times.count / 2] }
        }
        for attempt in timed {
            guard let median = medians[attempt.difficulty] else { continue }
            let fast = attempt.timeSpent < median
            switch (fast, attempt.correct) {
            case (true, true): result.fastRight += 1
            case (true, false): result.fastWrong += 1
            case (false, true): result.slowRight += 1
            case (false, false): result.slowWrong += 1
            }
        }
        return result
    }

    // MARK: Neglected skills

    var neglectedSkills: [AnalyticsNeglectedSkill] {
        let calendar = Calendar.current
        var lastSeen: [String: Date] = [:]
        for attempt in allAttempts {   // newest first, so first write wins
            if lastSeen[attempt.skillCd] == nil { lastSeen[attempt.skillCd] = attempt.date }
        }
        var stale: [AnalyticsNeglectedSkill] = []
        var untouched: [AnalyticsNeglectedSkill] = []
        for entry in SATCatalog.allSkills {
            if let seen = lastSeen[entry.skill.code] {
                let days = calendar.dateComponents([.day], from: seen, to: Date()).day ?? 0
                if days >= 10 {
                    stale.append(AnalyticsNeglectedSkill(
                        skillCd: entry.skill.code, skillName: entry.skill.name,
                        domain: entry.domain.name, section: entry.section.key,
                        daysSinceSeen: days))
                }
            } else {
                untouched.append(AnalyticsNeglectedSkill(
                    skillCd: entry.skill.code, skillName: entry.skill.name,
                    domain: entry.domain.name, section: entry.section.key,
                    daysSinceSeen: nil))
            }
        }
        stale.sort { ($0.daysSinceSeen ?? 0) > ($1.daysSinceSeen ?? 0) }
        // Only pad with never-attempted skills once the user has some history.
        let pad = allAttempts.isEmpty ? [] : untouched.prefix(max(0, 3 - stale.count))
        return Array((stale + pad).prefix(3))
    }

    // MARK: First try vs retry

    struct RetryStats {
        let firstTryAttempts: Int
        let firstTryCorrect: Int
        let retryAttempts: Int
        let retryCorrect: Int

        var firstTryAccuracy: Double? {
            firstTryAttempts > 0 ? Double(firstTryCorrect) / Double(firstTryAttempts) : nil
        }
        var retryAccuracy: Double? {
            retryAttempts > 0 ? Double(retryCorrect) / Double(retryAttempts) : nil
        }
    }

    var retryStats: RetryStats {
        var firstAttempts = 0, firstCorrect = 0, retryAttempts = 0, retryCorrect = 0
        var seen = Set<String>()
        // Oldest first so the chronological first attempt lands in "first try".
        for attempt in filtered.reversed() {
            if seen.insert(attempt.questionId).inserted {
                firstAttempts += 1
                if attempt.correct { firstCorrect += 1 }
            } else {
                retryAttempts += 1
                if attempt.correct { retryCorrect += 1 }
            }
        }
        return RetryStats(firstTryAttempts: firstAttempts, firstTryCorrect: firstCorrect,
                          retryAttempts: retryAttempts, retryCorrect: retryCorrect)
    }

    // MARK: Consistency heatmap (last 12 weeks, columns = weeks)

    struct HeatWeek: Identifiable {
        let weekStart: Date
        /// 7 entries, Sun..Sat (calendar order); nil = future day.
        let counts: [Int?]
        var id: Date { weekStart }
    }

    var heatWeeks: [HeatWeek] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var perDay: [Date: Int] = [:]
        for attempt in allAttempts {
            perDay[calendar.startOfDay(for: attempt.date), default: 0] += 1
        }
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        var weeks: [HeatWeek] = []
        for weekOffset in stride(from: -11, through: 0, by: 1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisWeek) else { continue }
            let counts: [Int?] = (0..<7).map { dayOffset in
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { return nil }
                return day > today ? nil : perDay[day, default: 0]
            }
            weeks.append(HeatWeek(weekStart: weekStart, counts: counts))
        }
        return weeks
    }

    var maxHeatCount: Int {
        heatWeeks.flatMap { $0.counts.compactMap { $0 } }.max() ?? 0
    }

    // MARK: Recent activity

    var recentAttempts: [AnalyticsAttempt] { Array(allAttempts.prefix(8)) }

    // MARK: Practice hand-off

    func practiceQuery(skillCd: String, domain: String, section: String) -> SATQuery {
        SATQuery(sections: [section], domains: [domain], skills: [skillCd], limit: 10)
    }
}

// MARK: - Shared formatting

enum AnalyticsFormat {
    /// "5h 6m", "31m", "46s"
    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// "1m 35s" style for per-question averages.
    static func shortDuration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(String(format: "%02d", seconds % 60))s"
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
