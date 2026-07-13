import Foundation
import Observation

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

    // MARK: - Data

    private(set) var stats: SATBankStats?
    private(set) var statsError: String?
    private(set) var isLoadingStats = false
    private(set) var skillProgress: [String: SATSkillStat] = [:]

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

    func resetFilters() {
        selectedSkills = []
        selectedDifficulties = []
        limit = nil
        randomize = false
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
