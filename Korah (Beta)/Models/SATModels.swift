import Foundation

// MARK: - SAT Question Models
// FINAL — matches normalizeQuestion() in korah-web api/_lib/collegeboard.js.
// /api/sat/q returns ALL fields below; /api/sat/qi returns ONLY the detail
// fields and the client OVERLAYS them onto the existing stub.

struct SATQuestion: Codable, Identifiable, Equatable {
    let id: String                  // canonical id (external_id | ibn | questionId)
    var detailKey: String = ""      // re-fetch key for /api/sat/qi
    var section: String = "english" // "english" | "math"
    var domain: String = ""         // human name, e.g. "Algebra"
    var skillCd: String = ""        // skill code, e.g. "H.A."
    var difficulty: String = ""     // "E" | "M" | "H"
    var paragraph: String = ""      // stimulus — College Board HTML
    var stem: String = ""           // question — HTML
    var options: [SATOption] = []   // [] for SPR (free-response)
    var correctAnswer: String = ""  // "A".."D" for mcq; numeric/text for spr
    var explanation: String = ""    // rationale — HTML
    var type: String = "mcq"        // "mcq" | "spr"
    var loaded: Bool = false        // false = stub; hydrate via /qi then overlay

    var isSPR: Bool { type == "spr" }

    mutating func overlay(_ d: SATQuestionDetail) {
        type = d.type
        paragraph = d.paragraph
        stem = d.stem
        options = d.options
        correctAnswer = d.correctAnswer
        explanation = d.explanation
        loaded = true
    }
}

struct SATOption: Codable, Identifiable, Equatable {
    let key: String    // "A" | "B" | "C" | "D"
    let text: String   // HTML
    var id: String { key }
}

/// /api/sat/qi response (detail fields only, no meta)
struct SATQuestionDetail: Codable {
    let id: String
    let type: String
    let paragraph: String
    let stem: String
    let options: [SATOption]
    let correctAnswer: String
    let explanation: String
}

/// /api/sat/q envelope
struct SATQuestionListResponse: Codable {
    let batchSize: Int
    let count: Int
    let questions: [SATQuestion]
}

// MARK: - Bank Stats (/api/sat/s)

struct SATDifficultyBucket: Codable {
    var total: Int = 0
    var E: Int = 0
    var M: Int = 0
    var H: Int = 0

    func count(for difficulties: Set<String>) -> Int {
        guard !difficulties.isEmpty else { return total }
        var sum = 0
        if difficulties.contains("E") { sum += E }
        if difficulties.contains("M") { sum += M }
        if difficulties.contains("H") { sum += H }
        return sum
    }
}

/// `data` payload of /api/sat/s. Breakdown keys are domain/skill CODES
/// (INI, CAS, H, P, … / CID, H.A., …), not human names.
struct SATBankStats: Codable {
    let totalQuestions: Int
    let domainBreakdown: [String: Int]
    let domainBreakdownByDifficulty: [String: SATDifficultyBucket]
    let difficultyBreakdown: SATDifficultyBucket
    let skillBreakdown: [String: Int]
    let skillBreakdownByDifficulty: [String: SATDifficultyBucket]

    enum CodingKeys: String, CodingKey {
        case totalQuestions, domainBreakdown, domainBreakdownByDifficulty
        case difficultyBreakdown, skillBreakdown, skillBreakdownByDifficulty
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalQuestions = try c.decodeIfPresent(Int.self, forKey: .totalQuestions) ?? 0
        domainBreakdown = try c.decodeIfPresent([String: Int].self, forKey: .domainBreakdown) ?? [:]
        domainBreakdownByDifficulty = try c.decodeIfPresent([String: SATDifficultyBucket].self, forKey: .domainBreakdownByDifficulty) ?? [:]
        skillBreakdown = try c.decodeIfPresent([String: Int].self, forKey: .skillBreakdown) ?? [:]
        skillBreakdownByDifficulty = try c.decodeIfPresent([String: SATDifficultyBucket].self, forKey: .skillBreakdownByDifficulty) ?? [:]
        // difficultyBreakdown arrives flat { E, M, H } without `total`
        let flat = try c.decodeIfPresent([String: Int].self, forKey: .difficultyBreakdown) ?? [:]
        var bucket = SATDifficultyBucket()
        bucket.E = flat["E"] ?? 0
        bucket.M = flat["M"] ?? 0
        bucket.H = flat["H"] ?? 0
        bucket.total = bucket.E + bucket.M + bucket.H
        difficultyBreakdown = bucket
    }
}

struct SATStatsResponse: Codable {
    let success: Bool
    let data: SATBankStats
}

// MARK: - AI Explanation (global satExplanations/{id} cache)

struct SATStep: Codable, Equatable {
    let title: String
    let body: String
}

struct SATExplanation: Codable, Equatable {
    let steps: [SATStep]
    let answer: String?
    let summary: String?
    let model: String?
    let createdAt: String?
}

// MARK: - Analytics (mirrors web sat-analytics.js Firestore schema)
// users/{uid}/satProfile/main, satTotals/summary, satSkills/{skillCd},
// satAttempts/{auto}, satBookmarks/{questionId}

struct SATProfile: Codable {
    var currentScore: Int?
    var goalScore: Int?
    var mathScore: Int?
    var englishScore: Int?
    var mathGoal: Int?
    var englishGoal: Int?
    /// ISO8601 date the user plans to sit the SAT (set during onboarding).
    var testDate: String?
    var createdAt: String?
    var updatedAt: String?
}

struct SATTotals: Codable {
    var totalXP: Int = 0
    var level: Int = 0
    var answered: Int = 0
    var correct: Int = 0
    var incorrect: Int = 0
    var practiceTime: Int = 0      // seconds, all-time
    var lastActivity: String?

    var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
}

struct SATSkillStat: Codable, Identifiable {
    var skillCd: String = ""
    var domain: String = ""
    var section: String = ""
    var attempts: Int = 0
    var correct: Int = 0
    var byDifficulty: [String: SATSkillDifficultyStat]?
    var lastSeen: String?

    var id: String { skillCd }
    var accuracy: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
}

struct SATSkillDifficultyStat: Codable {
    var attempts: Int = 0
    var correct: Int = 0
}

/// Append-only attempt log entry (users/{uid}/satAttempts)
struct SATAttempt: Codable, Identifiable {
    var id: String = UUID().uuidString
    var questionId: String
    var detailKey: String
    var legacyQuestionId: String = ""
    var type: String = ""
    var skillCd: String = "_unknown"
    var domain: String = ""
    var section: String = ""
    var difficulty: String = "E"
    var assessment: String = "SAT"
    var correct: Bool
    var xp: Int = 0
    var ts: String = ""
    var timeSpent: Int = 0

    enum CodingKeys: String, CodingKey {
        case questionId, detailKey, legacyQuestionId, type, skillCd, domain
        case section, difficulty, assessment, correct, xp, ts, timeSpent
    }
}

struct SATBookmark: Codable, Identifiable {
    var questionId: String
    var legacyQuestionId: String = ""
    var detailKey: String = ""
    var section: String = ""
    var domain: String = ""
    var skillCd: String = ""
    var ts: String = ""

    var id: String { questionId }
}

// MARK: - XP rules (mirror web sat-analytics.js)

enum SATXP {
    static let levelThreshold = 1000

    static func forCorrect(_ difficulty: String) -> Int {
        switch difficulty {
        case "H": return 30
        case "M": return 20
        default: return 10
        }
    }

    static func forIncorrect(_ difficulty: String) -> Int {
        forCorrect(difficulty) / 2
    }

    static func level(for xp: Int) -> Int {
        max(0, xp) / levelThreshold
    }
}

// MARK: - Catalog (mirrors web sat-shared.js OPENSAT_CATALOG)

struct SATSkillInfo: Identifiable, Hashable {
    let name: String   // e.g. "Linear functions"
    let code: String   // e.g. "H.B."
    var id: String { code }
}

struct SATDomainInfo: Identifiable, Hashable {
    let name: String        // e.g. "Algebra" (matches /api/sat/q domain names)
    let code: String        // e.g. "H" (matches /api/sat/s breakdown keys)
    let blurb: String
    let skills: [SATSkillInfo]
    var id: String { code }
}

struct SATSectionInfo: Identifiable, Hashable {
    let key: String         // "english" | "math"
    let label: String
    let domains: [SATDomainInfo]
    var id: String { key }
}

enum SATCatalog {
    static let assessments = ["SAT", "PSAT/NMSQT", "PSAT"]
    static let difficulties: [(code: String, label: String)] = [
        ("E", "Easy"), ("M", "Medium"), ("H", "Hard"),
    ]
    static let difficultyLabels = ["E": "Easy", "M": "Medium", "H": "Hard"]
    static let sectionLabels = ["english": "Reading & Writing", "math": "Math"]

    static let english = SATSectionInfo(
        key: "english",
        label: "English Reading & Writing",
        domains: [
            SATDomainInfo(
                name: "Information and Ideas", code: "INI",
                blurb: "Interpret details, make inferences, and synthesize claims across passages.",
                skills: [
                    SATSkillInfo(name: "Central Ideas and Details", code: "CID"),
                    SATSkillInfo(name: "Inferences", code: "INF"),
                    SATSkillInfo(name: "Command of Evidence", code: "COE"),
                ]),
            SATDomainInfo(
                name: "Craft and Structure", code: "CAS",
                blurb: "Analyze word choice, text structure, rhetoric, and point of view.",
                skills: [
                    SATSkillInfo(name: "Words in Context", code: "WIC"),
                    SATSkillInfo(name: "Text Structure and Purpose", code: "TSP"),
                    SATSkillInfo(name: "Cross-Text Connections", code: "CTC"),
                ]),
            SATDomainInfo(
                name: "Expression of Ideas", code: "EOI",
                blurb: "Revise for clarity, organization, transitions, and rhetorical effectiveness.",
                skills: [
                    SATSkillInfo(name: "Rhetorical Synthesis", code: "SYN"),
                    SATSkillInfo(name: "Transitions", code: "TRA"),
                ]),
            SATDomainInfo(
                name: "Standard English Conventions", code: "SEC",
                blurb: "Sentence boundaries, punctuation, agreement, and usage rules.",
                skills: [
                    SATSkillInfo(name: "Boundaries", code: "BOU"),
                    SATSkillInfo(name: "Form, Structure, and Sense", code: "FSS"),
                ]),
        ])

    static let math = SATSectionInfo(
        key: "math",
        label: "Math",
        domains: [
            SATDomainInfo(
                name: "Algebra", code: "H",
                blurb: "Linear equations, systems, inequalities, and algebraic fluency.",
                skills: [
                    SATSkillInfo(name: "Linear equations in one variable", code: "H.A."),
                    SATSkillInfo(name: "Linear functions", code: "H.B."),
                    SATSkillInfo(name: "Linear equations in two variables", code: "H.C."),
                    SATSkillInfo(name: "Systems of two linear equations in two variables", code: "H.D."),
                    SATSkillInfo(name: "Linear inequalities in one or two variables", code: "H.E."),
                ]),
            SATDomainInfo(
                name: "Advanced Math", code: "P",
                blurb: "Nonlinear functions, equivalent expressions, and higher-order structure.",
                skills: [
                    SATSkillInfo(name: "Equivalent expressions", code: "P.A."),
                    SATSkillInfo(name: "Nonlinear equations in one variable and systems of equations", code: "P.B."),
                    SATSkillInfo(name: "Nonlinear functions", code: "P.C."),
                ]),
            SATDomainInfo(
                name: "Problem-Solving and Data Analysis", code: "Q",
                blurb: "Ratios, rates, percentages, probability, and data interpretation.",
                skills: [
                    SATSkillInfo(name: "Ratios, rates, proportional relationships, and units", code: "Q.A."),
                    SATSkillInfo(name: "Percentages", code: "Q.B."),
                    SATSkillInfo(name: "One-variable data: Distributions and measures of center", code: "Q.C."),
                    SATSkillInfo(name: "Two-variable data: Models and scatterplots", code: "Q.D."),
                    SATSkillInfo(name: "Probability and conditional probability", code: "Q.E."),
                    SATSkillInfo(name: "Inference from sample statistics and margin of error", code: "Q.F."),
                    SATSkillInfo(name: "Evaluating statistical claims: Observational studies", code: "Q.G."),
                ]),
            SATDomainInfo(
                name: "Geometry and Trigonometry", code: "S",
                blurb: "Angles, circles, area, volume, right triangles, and trig relationships.",
                skills: [
                    SATSkillInfo(name: "Area and volume", code: "S.A."),
                    SATSkillInfo(name: "Lines, angles, and triangles", code: "S.B."),
                    SATSkillInfo(name: "Right triangles and trigonometry", code: "S.C."),
                    SATSkillInfo(name: "Circles", code: "S.D."),
                ]),
        ])

    static let sections: [SATSectionInfo] = [english, math]

    static func section(forDomainName name: String) -> String? {
        for section in sections where section.domains.contains(where: { $0.name == name }) {
            return section.key
        }
        return nil
    }

    static func skillName(forCode code: String) -> String? {
        for section in sections {
            for domain in section.domains {
                if let skill = domain.skills.first(where: { $0.code == code }) {
                    return skill.name
                }
            }
        }
        return nil
    }

    static var allSkills: [(skill: SATSkillInfo, domain: SATDomainInfo, section: SATSectionInfo)] {
        sections.flatMap { section in
            section.domains.flatMap { domain in
                domain.skills.map { ($0, domain, section) }
            }
        }
    }
}

// MARK: - SPR answer normalization (mirrors web normalizeSprAnswer)

enum SATAnswerCheck {
    /// Trim, lowercase, strip spaces, fix leading decimal (".75" → "0.75").
    static func normalizeSPR(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        v = v.replacingOccurrences(of: " ", with: "")
        if v.hasPrefix(".") { v = "0" + v }
        if v.hasPrefix("-.") { v = "-0" + v.dropFirst(1) }
        return v
    }

    static func isCorrect(question: SATQuestion, answer: String) -> Bool {
        if question.isSPR {
            return normalizeSPR(answer) == normalizeSPR(question.correctAnswer)
        }
        return answer == question.correctAnswer
    }
}
