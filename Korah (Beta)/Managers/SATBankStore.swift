import Foundation
import Observation

// MARK: - Question-level filter options (Question Bank filter bar)
// Mirror the web bank's Time Spent / Completed / Result chips. Backed by
// per-question analytics (SATAnalyticsService), joined client-side after a
// question list is fetched — the College Board API has no server-side
// support for these.

enum SATCompletionFilter: String, CaseIterable, Identifiable {
    case any = "Any"
    case completed = "Completed"
    case notCompleted = "Not completed"
    var id: String { rawValue }
}

enum SATResultFilter: String, CaseIterable, Identifiable {
    case any = "Any"
    case correct = "Correct"
    case incorrect = "Incorrect"
    var id: String { rawValue }
}

enum SATTimeSpentFilter: String, CaseIterable, Identifiable {
    case any = "Any"
    case under1 = "Under 1 min"
    case oneToThree = "1–3 min"
    case threePlus = "3+ min"
    var id: String { rawValue }

    func matches(_ seconds: Int) -> Bool {
        switch self {
        case .any: return true
        case .under1: return seconds < 60
        case .oneToThree: return seconds >= 60 && seconds < 180
        case .threePlus: return seconds >= 180
        }
    }
}

// MARK: - SAT bank filter/selection state + global stats + per-skill progress.
// Backs SATBankView (topic table) and SATHomeView (stats strip).

@MainActor
@Observable
final class SATBankStore {

    static let shared = SATBankStore()

    // MARK: - Filter selection

    var assessment: String = "SAT" {
        didSet { if oldValue != assessment { Task { await loadStats(force: true) } } }
    }
    var selectedSkills: Set<String> = []        // skill codes
    var selectedDifficulties: Set<String> = []  // E/M/H; empty = any
    var limit: Int? = nil
    var randomize: Bool = false

    // Question-level filters (Saved / Completed / Result / Time Spent) —
    // applied client-side by SATPlayerSession after fetching, since the API
    // only knows about sections/domains/skills/difficulties.
    var savedOnly: Bool = false
    var completionFilter: SATCompletionFilter = .any
    var resultFilter: SATResultFilter = .any
    var timeSpentFilter: SATTimeSpentFilter = .any

    // MARK: - Data

    private(set) var stats: SATBankStats?
    private(set) var statsError: String?
    private(set) var isLoadingStats = false
    private(set) var skillProgress: [String: SATSkillStat] = [:]
    private(set) var bookmarkedIds: Set<String> = []
    private(set) var outcomes: [String: (correct: Bool, timeSpent: Int)] = [:]

    private init() {}

    // MARK: - Loading

    func loadIfNeeded() async {
        if stats == nil { await loadStats() }
        await loadProgress()
    }

    func loadStats(force: Bool = false) async {
        if isLoadingStats { return }
        if stats != nil && !force { return }
        isLoadingStats = true
        statsError = nil
        defer { isLoadingStats = false }
        do {
            stats = try await SATService.shared.fetchStats(assessment: assessment)
        } catch {
            statsError = error.localizedDescription
        }
    }

    func loadProgress() async {
        let list = (try? await SATAnalyticsService.shared.getAllSkillStats()) ?? []
        skillProgress = Dictionary(uniqueKeysWithValues: list.map { ($0.skillCd, $0) })
        outcomes = (try? await SATAnalyticsService.shared.getLatestOutcomes()) ?? [:]
        let bookmarks = (try? await SATAnalyticsService.shared.getBookmarks()) ?? []
        bookmarkedIds = Set(bookmarks.map(\.id))
    }

    // MARK: - Question-level filtering (Saved / Completed / Result / Time Spent)
    // Applied client-side by SATPlayerSession after fetching a question list.

    var hasQuestionLevelFilters: Bool {
        savedOnly || completionFilter != .any || resultFilter != .any || timeSpentFilter != .any
    }

    var hasActiveFilters: Bool {
        assessment != "SAT" || !selectedDifficulties.isEmpty || limit != nil || hasQuestionLevelFilters
    }

    func matchesQuestionFilters(_ question: SATQuestion) -> Bool {
        let key = question.detailKey.isEmpty ? question.id : question.detailKey
        if savedOnly && !bookmarkedIds.contains(key) { return false }

        let outcome = outcomes[key]
        switch completionFilter {
        case .any: break
        case .completed: if outcome == nil { return false }
        case .notCompleted: if outcome != nil { return false }
        }
        switch resultFilter {
        case .any: break
        case .correct: if outcome?.correct != true { return false }
        case .incorrect: if outcome == nil || outcome!.correct { return false }
        }
        if timeSpentFilter != .any {
            guard let outcome, timeSpentFilter.matches(outcome.timeSpent) else { return false }
        }
        return true
    }

    // MARK: - Counts (respect the active difficulty filter, like the web bank)

    func questionCount(forSkill code: String) -> Int {
        guard let stats else { return 0 }
        if selectedDifficulties.isEmpty { return stats.skillBreakdown[code] ?? 0 }
        return stats.skillBreakdownByDifficulty[code]?.count(for: selectedDifficulties) ?? 0
    }

    func questionCount(forDomain code: String) -> Int {
        guard let stats else { return 0 }
        if selectedDifficulties.isEmpty { return stats.domainBreakdown[code] ?? 0 }
        return stats.domainBreakdownByDifficulty[code]?.count(for: selectedDifficulties) ?? 0
    }

    func questionCount(forSection section: SATSectionInfo) -> Int {
        section.domains.reduce(0) { $0 + questionCount(forDomain: $1.code) }
    }

    /// (attempts, correct) for a skill, narrowed to the difficulty filter.
    func progress(forSkill code: String) -> (attempts: Int, correct: Int) {
        guard let stat = skillProgress[code] else { return (0, 0) }
        if selectedDifficulties.isEmpty { return (stat.attempts, stat.correct) }
        var attempts = 0, correct = 0
        for difficulty in selectedDifficulties {
            if let bucket = stat.byDifficulty?[difficulty] {
                attempts += bucket.attempts
                correct += bucket.correct
            }
        }
        return (attempts, correct)
    }

    // MARK: - Selection helpers (mirror web toggle semantics)

    func isSkillSelected(_ code: String) -> Bool { selectedSkills.contains(code) }

    func isDomainSelected(_ domain: SATDomainInfo) -> Bool {
        !domain.skills.isEmpty && domain.skills.allSatisfy { selectedSkills.contains($0.code) }
    }

    func isSectionSelected(_ section: SATSectionInfo) -> Bool {
        section.domains.allSatisfy { isDomainSelected($0) }
    }

    func toggleSkill(_ code: String) {
        if selectedSkills.contains(code) { selectedSkills.remove(code) }
        else { selectedSkills.insert(code) }
    }

    func toggleDomain(_ domain: SATDomainInfo) {
        let codes = domain.skills.map(\.code)
        if isDomainSelected(domain) {
            codes.forEach { selectedSkills.remove($0) }
        } else {
            codes.forEach { selectedSkills.insert($0) }
        }
    }

    func toggleSection(_ section: SATSectionInfo) {
        if isSectionSelected(section) {
            section.domains.flatMap(\.skills).forEach { selectedSkills.remove($0.code) }
        } else {
            section.domains.flatMap(\.skills).forEach { selectedSkills.insert($0.code) }
        }
    }

    /// Resets the filter bar (Question set / Difficulty / Limit / Saved /
    /// Completed / Result / Time Spent). Leaves the topic accordion's
    /// `selectedSkills` untouched — that's a separate concern from the
    /// question-list filters.
    func resetFilters() {
        selectedDifficulties = []
        limit = nil
        savedOnly = false
        completionFilter = .any
        resultFilter = .any
        timeSpentFilter = .any
        if assessment != "SAT" { assessment = "SAT" }
    }

    // MARK: - Query construction

    /// Domains + sections implied by the current skill selection.
    var buildQuery: SATQuery {
        var sections: Set<String> = []
        var domains: Set<String> = []
        for entry in SATCatalog.allSkills where selectedSkills.contains(entry.skill.code) {
            sections.insert(entry.section.key)
            domains.insert(entry.domain.name)
        }
        return SATQuery(
            sections: sections,
            domains: domains,
            skills: selectedSkills,
            difficulties: selectedDifficulties,
            assessment: assessment,
            limit: limit,
            random: randomize
        )
    }

    var selectedTopicCount: Int { selectedSkills.count }
}
