import Foundation
import Observation

// MARK: - One practice session in the SAT player.
// Owns the question list, per-question answer state, lazy stub hydration
// (prefetch window like the web player), the stopwatch, and attempt logging.

@MainActor
@Observable
final class SATPlayerSession {

    enum LoadState: Equatable {
        case loading
        case ready
        case empty
        case error(String)
    }

    // MARK: - Session data

    let query: SATQuery
    private(set) var questions: [SATQuestion] = []
    private(set) var loadState: LoadState = .loading

    var currentIndex: Int = 0 {
        didSet {
            guard oldValue != currentIndex else { return }
            explanationShown = false
            restartStopwatch()
            Task { await hydrate(around: currentIndex) }
        }
    }

    // Per-question state, keyed by question id
    private(set) var answers: [String: String] = [:]
    private(set) var checked: Set<String> = []
    private(set) var eliminated: [String: Set<String>] = [:]
    private(set) var bookmarked: Set<String> = []
    private(set) var earnedXP: [String: Int] = [:]

    /// Whether the latest check for a question was correct — populated live
    /// by `check()` and restored from Firestore on `load()` so questions
    /// answered in a prior session still show their result here.
    private(set) var correctness: [String: Bool] = [:]
    /// Question ids that had at least one incorrect attempt before their
    /// latest (current) result — drives the "correct after retries" pill.
    private(set) var hadIncorrectAttempt: Set<String> = []

    /// "Explain" toggled open before checking (preview) — per current question.
    var explanationShown = false

    // MARK: - Stopwatch

    private(set) var stopwatchElapsed = 0
    var stopwatchPaused = false
    private var stopwatchTask: Task<Void, Never>?

    // MARK: - Hydration

    private var hydrating: Set<Int> = []

    init(query: SATQuery) {
        self.query = query
    }
    // No deinit needed: the stopwatch task holds `self` weakly and exits on
    // its next tick after the session deallocates.

    // MARK: - Loading

    func load() async {
        loadState = .loading
        do {
            // Bank progress (prior attempt outcomes) may not have been
            // loaded yet depending on how the player was entered — refresh
            // it so previously answered questions restore correctly below.
            let bank = SATBankStore.shared
            await bank.loadProgress()
            let response = try await SATService.shared.fetchQuestions(query)
            questions = bank.hasQuestionLevelFilters
                ? response.questions.filter(bank.matchesQuestionFilters)
                : response.questions
            restorePriorOutcomes(bank: bank)
            loadState = questions.isEmpty ? .empty : .ready
            currentIndex = 0
            restartStopwatch()
            await syncBookmarks()
            await hydrate(around: 0, radius: 6)
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    /// Restore checked/correct state for questions already attempted in a
    /// previous session, keyed by the same canonical id used when the
    /// attempt was recorded (detailKey, falling back to id).
    private func restorePriorOutcomes(bank: SATBankStore) {
        for question in questions {
            let key = question.detailKey.isEmpty ? question.id : question.detailKey
            guard let outcome = bank.outcomes[key] else { continue }
            checked.insert(question.id)
            correctness[question.id] = outcome.correct
            if outcome.hadIncorrect { hadIncorrectAttempt.insert(question.id) }
        }
    }

    // MARK: - Accessors

    var currentQuestion: SATQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    func answer(for question: SATQuestion) -> String? { answers[question.id] }
    func isChecked(_ question: SATQuestion) -> Bool { checked.contains(question.id) }
    func isBookmarked(_ question: SATQuestion) -> Bool { bookmarked.contains(question.id) }
    func eliminatedKeys(for question: SATQuestion) -> Set<String> { eliminated[question.id] ?? [] }

    func isCorrect(_ question: SATQuestion) -> Bool {
        if let known = correctness[question.id] { return known }
        guard let answer = answers[question.id] else { return false }
        return SATAnswerCheck.isCorrect(question: question, answer: answer)
    }

    /// Navigator pill state: unanswered | attempted | correct | incorrect |
    /// correctAfterRetry. `checked` (not `answers`) is the source of truth
    /// for correct/incorrect since it's restored from Firestore even when
    /// the exact prior answer text isn't known.
    func pillState(for question: SATQuestion) -> String {
        if checked.contains(question.id) {
            if isCorrect(question) {
                return hadIncorrectAttempt.contains(question.id) ? "correctAfterRetry" : "correct"
            }
            return "incorrect"
        }
        guard let answer = answers[question.id], !answer.isEmpty else { return "unanswered" }
        return "attempted"
    }

    var answeredCount: Int { checked.count }
    var correctCount: Int {
        questions.filter { checked.contains($0.id) && isCorrect($0) }.count
    }

    // MARK: - Answering

    func select(answer: String, for question: SATQuestion) {
        guard !checked.contains(question.id) else { return }
        answers[question.id] = answer
    }

    func toggleEliminate(key: String, for question: SATQuestion) {
        guard !checked.contains(question.id) else { return }
        var set = eliminated[question.id] ?? []
        if set.contains(key) {
            set.remove(key)
        } else {
            set.insert(key)
            if answers[question.id] == key {
                answers[question.id] = nil
            }
        }
        eliminated[question.id] = set
    }

    /// Grade the current answer; logs to Firestore the first time only.
    func check(_ question: SATQuestion, assessment: String = "SAT") {
        guard let answer = answers[question.id],
              !answer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let firstCheck = !checked.contains(question.id)
        checked.insert(question.id)
        guard firstCheck else { return }
        let correct = SATAnswerCheck.isCorrect(question: question, answer: answer)
        if !correct { hadIncorrectAttempt.insert(question.id) }
        correctness[question.id] = correct
        let elapsed = stopwatchElapsed
        Task {
            let xp = (try? await SATAnalyticsService.shared.recordAttempt(
                question: question, correct: correct, timeSpent: elapsed,
                assessment: assessment, mode: "player")) ?? 0
            earnedXP[question.id] = xp
        }
    }

    func toggleBookmark(_ question: SATQuestion) {
        let newValue = !bookmarked.contains(question.id)
        if newValue { bookmarked.insert(question.id) } else { bookmarked.remove(question.id) }
        Task {
            try? await SATAnalyticsService.shared.saveBookmark(question: question, bookmarked: newValue)
        }
    }

    private func syncBookmarks() async {
        guard let saved = try? await SATAnalyticsService.shared.getBookmarks() else { return }
        let savedIds = Set(saved.map(\.questionId))
        for question in questions {
            let key = question.detailKey.isEmpty ? question.id : question.detailKey
            if savedIds.contains(key) { bookmarked.insert(question.id) }
        }
    }

    // MARK: - Lazy hydration (stub → detail, with prefetch window)

    func hydrate(around index: Int, radius: Int = 4) async {
        await ensureDetail(at: index)
        for offset in 1...radius {
            let forward = index + offset
            if forward < questions.count {
                Task { await self.ensureDetail(at: forward) }
            }
        }
        // Prefetch one question behind too, so swiping back after a check
        // doesn't hit a stub.
        let backward = index - 1
        if backward >= 0 {
            Task { await self.ensureDetail(at: backward) }
        }
    }

    func ensureDetail(at index: Int) async {
        guard questions.indices.contains(index) else { return }
        let question = questions[index]
        guard !question.loaded, !hydrating.contains(index) else { return }
        let key = question.detailKey.isEmpty ? question.id : question.detailKey
        guard !key.isEmpty else { return }
        hydrating.insert(index)
        defer { hydrating.remove(index) }
        do {
            let detail = try await SATService.shared.fetchDetail(id: key)
            guard questions.indices.contains(index), questions[index].id == question.id else { return }
            questions[index].overlay(detail)
        } catch {
            // Leave as stub; the page shows a retry affordance.
        }
    }

    // MARK: - Stopwatch

    func restartStopwatch() {
        flushPracticeTime()
        stopwatchTask?.cancel()
        stopwatchElapsed = 0
        stopwatchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if !self.stopwatchPaused { self.stopwatchElapsed += 1 }
            }
        }
    }

    /// Push unlogged question-facing time into the all-time total
    /// (mirrors the web player's flushPracticeTime).
    func flushPracticeTime() {
        let elapsed = stopwatchElapsed
        stopwatchElapsed = 0
        guard elapsed > 0 else { return }
        Task { await SATAnalyticsService.shared.recordPracticeTime(seconds: elapsed) }
    }

    func endSession() {
        flushPracticeTime()
        stopwatchTask?.cancel()
        stopwatchTask = nil
    }

    var stopwatchText: String {
        let minutes = stopwatchElapsed / 60
        let seconds = stopwatchElapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
