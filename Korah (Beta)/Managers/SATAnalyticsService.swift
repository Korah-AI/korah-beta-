import Foundation
import FirebaseFirestore

// MARK: - SAT analytics — Firestore-backed.
// Mirrors korah-web sat/js/sat-analytics.js so progress is shared with the web app:
//   users/{uid}/satProfile/main       — { currentScore, goalScore, mathScore, … }
//   users/{uid}/satTotals/summary     — { totalXP, level, answered, correct, incorrect, practiceTime }
//   users/{uid}/satSkills/{skillCd}   — per-skill aggregate (+byDifficulty)
//   users/{uid}/satAttempts/{auto}    — append-only attempt log
//   users/{uid}/satBookmarks/{qid}    — saved questions

@MainActor
final class SATAnalyticsService {

    static let shared = SATAnalyticsService()
    private init() {}

    private var db: Firestore { Firestore.firestore() }

    private var uid: String? { AuthManager.shared.currentUser?.id }

    private func isoNow() -> String {
        ISO8601DateFormatter.satShared.string(from: Date())
    }

    private func userDoc(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: - Profile

    func getProfile() async throws -> SATProfile? {
        guard let uid else { return nil }
        let snap = try await userDoc(uid).collection("satProfile").document("main").getDocument()
        guard snap.exists else { return nil }
        return try? snap.data(as: SATProfile.self)
    }

    func saveProfile(mathScore: Int?, englishScore: Int?, mathGoal: Int?, englishGoal: Int?) async throws {
        guard let uid else { return }
        let existing = try? await getProfile()
        let now = isoNow()

        let resolvedMathScore = mathScore ?? existing?.mathScore
        let resolvedEnglishScore = englishScore ?? existing?.englishScore
        let resolvedMathGoal = mathGoal ?? existing?.mathGoal
        let resolvedEnglishGoal = englishGoal ?? existing?.englishGoal

        var payload: [String: Any] = ["updatedAt": now]
        payload["createdAt"] = existing?.createdAt ?? now
        payload["mathScore"] = resolvedMathScore as Any
        payload["englishScore"] = resolvedEnglishScore as Any
        payload["mathGoal"] = resolvedMathGoal as Any
        payload["englishGoal"] = resolvedEnglishGoal as Any
        if let m = resolvedMathScore, let e = resolvedEnglishScore {
            payload["currentScore"] = m + e
        }
        if let m = resolvedMathGoal, let e = resolvedEnglishGoal {
            payload["goalScore"] = m + e
        }
        try await userDoc(uid).collection("satProfile").document("main")
            .setData(payload, merge: true)
    }

    /// Saves the date the user plans to take the SAT (from onboarding).
    func saveTestDate(_ date: Date) async throws {
        guard let uid else { return }
        try await userDoc(uid).collection("satProfile").document("main").setData([
            "testDate": ISO8601DateFormatter.satShared.string(from: date),
            "updatedAt": isoNow()
        ], merge: true)
    }

    // MARK: - Totals

    func getTotals() async throws -> SATTotals {
        guard let uid else { return SATTotals() }
        let snap = try await userDoc(uid).collection("satTotals").document("summary").getDocument()
        guard snap.exists, let totals = try? snap.data(as: SATTotals.self) else { return SATTotals() }
        return totals
    }

    // MARK: - Record attempt (batched: attempt log + skill aggregate + totals)

    @discardableResult
    func recordAttempt(question: SATQuestion, correct: Bool, timeSpent: Int,
                       assessment: String = "SAT") async throws -> Int {
        guard let uid else { return 0 }
        let questionId = question.detailKey.isEmpty ? question.id : question.detailKey
        let diff = ["E", "M", "H"].contains(question.difficulty) ? question.difficulty : "E"
        let xp = correct ? SATXP.forCorrect(diff) : -SATXP.forIncorrect(diff)
        let skillCd = question.skillCd.isEmpty ? "_unknown" : question.skillCd
        let now = isoNow()

        let totals = try await getTotals()
        let newXP = max(0, totals.totalXP + xp)

        let batch = db.batch()

        // Attempt log
        let attemptRef = userDoc(uid).collection("satAttempts").document()
        batch.setData([
            "questionId": questionId,
            "detailKey": questionId,
            "legacyQuestionId": question.id,
            "type": question.type,
            "skillCd": skillCd,
            "domain": question.domain,
            "section": question.section,
            "difficulty": diff,
            "assessment": assessment,
            "correct": correct,
            "xp": xp,
            "ts": now,
            "timeSpent": timeSpent,
        ], forDocument: attemptRef)

        // Skill aggregate
        let skillRef = userDoc(uid).collection("satSkills").document(skillCd)
        batch.setData([
            "skillCd": skillCd,
            "domain": question.domain,
            "section": question.section,
            "attempts": FieldValue.increment(Int64(1)),
            "correct": FieldValue.increment(Int64(correct ? 1 : 0)),
            "byDifficulty.\(diff).attempts": FieldValue.increment(Int64(1)),
            "byDifficulty.\(diff).correct": FieldValue.increment(Int64(correct ? 1 : 0)),
            "lastSeen": now,
        ], forDocument: skillRef, merge: true)

        // Totals
        let totalsRef = userDoc(uid).collection("satTotals").document("summary")
        batch.setData([
            "totalXP": newXP,
            "level": SATXP.level(for: newXP),
            "answered": FieldValue.increment(Int64(1)),
            "correct": FieldValue.increment(Int64(correct ? 1 : 0)),
            "incorrect": FieldValue.increment(Int64(correct ? 0 : 1)),
            "lastActivity": now,
        ], forDocument: totalsRef, merge: true)

        try await batch.commit()
        return xp
    }

    /// Add question-facing time to the all-time practice total (even when the
    /// user never checks an answer). Safe to call with 0; it no-ops.
    func recordPracticeTime(seconds: Int) async {
        guard let uid, seconds > 0 else { return }
        try? await userDoc(uid).collection("satTotals").document("summary").setData([
            "practiceTime": FieldValue.increment(Int64(seconds)),
            "lastActivity": isoNow(),
        ], merge: true)
    }

    // MARK: - Bookmarks

    func saveBookmark(question: SATQuestion, bookmarked: Bool) async throws {
        guard let uid else { return }
        let questionId = question.detailKey.isEmpty ? question.id : question.detailKey
        let ref = userDoc(uid).collection("satBookmarks").document(questionId)
        if bookmarked {
            try await ref.setData([
                "questionId": questionId,
                "legacyQuestionId": question.id,
                "detailKey": questionId,
                "section": question.section,
                "domain": question.domain,
                "skillCd": question.skillCd,
                "ts": isoNow(),
            ])
        } else {
            try await ref.delete()
        }
    }

    func getBookmarks() async throws -> [SATBookmark] {
        guard let uid else { return [] }
        let snap = try await userDoc(uid).collection("satBookmarks").getDocuments()
        return snap.documents.compactMap { try? $0.data(as: SATBookmark.self) }
    }

    // MARK: - Skill stats & attempts

    func getAllSkillStats() async throws -> [SATSkillStat] {
        guard let uid else { return [] }
        let snap = try await userDoc(uid).collection("satSkills").getDocuments()
        return snap.documents.compactMap { try? $0.data(as: SATSkillStat.self) }
    }

    func getRecentAttempts(limit: Int = 20) async throws -> [SATAttempt] {
        guard let uid else { return [] }
        let snap = try await userDoc(uid).collection("satAttempts")
            .order(by: "ts", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snap.documents.compactMap { doc in
            var attempt = try? doc.data(as: SATAttempt.self)
            attempt?.id = doc.documentID
            return attempt
        }
    }

    /// Latest attempt outcome per question, keyed by canonical id.
    func getLatestOutcomes() async throws -> [String: (correct: Bool, timeSpent: Int)] {
        guard let uid else { return [:] }
        let snap = try await userDoc(uid).collection("satAttempts")
            .order(by: "ts", descending: true)
            .getDocuments()
        var map: [String: (Bool, Int)] = [:]
        for doc in snap.documents {
            let data = doc.data()
            let id = (data["detailKey"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (data["questionId"] as? String) ?? ""
            guard !id.isEmpty, map[id] == nil else { continue }
            map[id] = (data["correct"] as? Bool ?? false, data["timeSpent"] as? Int ?? 0)
        }
        return map
    }

    /// Missed question ids (latest attempt per question was incorrect),
    /// grouped by section.
    func getMissedBySection(limitPerSection: Int = 50) async throws -> (english: [String], math: [String]) {
        guard let uid else { return ([], []) }
        let snap = try await userDoc(uid).collection("satAttempts")
            .order(by: "ts", descending: true)
            .getDocuments()
        var latest: [String: (correct: Bool, section: String)] = [:]
        for doc in snap.documents {
            let data = doc.data()
            let id = (data["detailKey"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (data["questionId"] as? String) ?? ""
            guard !id.isEmpty, latest[id] == nil else { continue }
            latest[id] = (data["correct"] as? Bool ?? false, data["section"] as? String ?? "")
        }
        var english: [String] = []
        var math: [String] = []
        for (id, info) in latest where !info.correct {
            if info.section == "english", english.count < limitPerSection { english.append(id) }
            else if info.section == "math", math.count < limitPerSection { math.append(id) }
        }
        return (english, math)
    }

    // MARK: - Suggestions (mirrors web suggestSkills weakness scoring)

    struct SkillSuggestion: Identifiable {
        let skillCd: String
        let skillName: String
        let domain: String
        let section: String
        let attempts: Int
        let correct: Int
        let accuracy: Double
        let weakness: Double
        var id: String { skillCd }
    }

    func suggestSkills(top: Int = 3) async throws -> [SkillSuggestion] {
        async let statsTask = getAllSkillStats()
        async let profileTask = getProfile()
        let (skillStats, profile) = try await (statsTask, profileTask)

        let byCode = Dictionary(uniqueKeysWithValues: skillStats.map { ($0.skillCd, $0) })
        let gap: Int = {
            if let cur = profile?.currentScore, let goal = profile?.goalScore {
                return max(0, goal - cur)
            }
            return 200
        }()
        let uncoveredBoost = gap > 100 ? 0.25 : 0.0

        var scored: [SkillSuggestion] = SATCatalog.allSkills.map { entry in
            let agg = byCode[entry.skill.code]
            let attempts = agg?.attempts ?? 0
            let correct = agg?.correct ?? 0
            let accuracy = attempts > 0 ? Double(correct) / Double(attempts) : 0
            let confidence = min(1.0, Double(attempts) / 10.0)
            var weakness = attempts > 0
                ? (1 - accuracy) * confidence + 0.3 * (1 - confidence)
                : 0.4
            if attempts == 0 { weakness += uncoveredBoost }
            return SkillSuggestion(
                skillCd: entry.skill.code, skillName: entry.skill.name,
                domain: entry.domain.name, section: entry.section.key,
                attempts: attempts, correct: correct,
                accuracy: accuracy, weakness: weakness
            )
        }
        scored.sort { $0.weakness > $1.weakness }
        return Array(scored.prefix(top))
    }

    /// Accuracy grouped by domain for the dashboard breakdown.
    struct DomainAccuracy: Identifiable {
        let domain: String
        let section: String
        let attempts: Int
        let correct: Int
        var accuracy: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
        var id: String { domain }
    }

    func getDomainBreakdown() async throws -> [DomainAccuracy] {
        let skillStats = try await getAllSkillStats()
        var map: [String: (section: String, attempts: Int, correct: Int)] = [:]
        for stat in skillStats {
            let key = stat.domain.isEmpty ? "Unknown" : stat.domain
            var current = map[key] ?? (stat.section, 0, 0)
            current.attempts += stat.attempts
            current.correct += stat.correct
            map[key] = current
        }
        return map.map { DomainAccuracy(domain: $0.key, section: $0.value.section,
                                        attempts: $0.value.attempts, correct: $0.value.correct) }
    }
}

// MARK: - Shared ISO formatter (web writes new Date().toISOString())

extension ISO8601DateFormatter {
    static let satShared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
