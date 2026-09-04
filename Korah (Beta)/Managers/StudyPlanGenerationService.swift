import Foundation
import UIKit

// MARK: - AI study plan generation
// Turns the setup wizard's intake into a validated StudyPlan via the /api/r
// chat proxy (JSON mode), plus vision extraction of scores from a practice
// report screenshot. Feedback is structurally capped (headline, max 3
// priorities, one weekly focus line) so it never overwhelms.

enum StudyPlanGenerationError: LocalizedError {
    case badResponse
    case noSessions

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Korah couldn't build a plan from that. Please try again."
        case .noSessions: return "The plan came back empty. Please try again."
        }
    }
}

struct ExtractedScores {
    var mathScore: Int?
    var englishScore: Int?
    /// Domain code -> 1 (needs work) ... 3 (strong), read off the report's
    /// Knowledge and Skills breakdown. Empty when the report doesn't show one.
    var domains: [String: Int] = [:]
}

/// Canonical domain codes, shared with the web app and with SATCatalog.
enum StudyPlanDomains {
    /// Math first, then Reading & Writing, matching the confidence step order.
    static let ordered: [(code: String, name: String)] = [
        ("H", "Algebra"),
        ("P", "Advanced Math"),
        ("Q", "Problem-Solving and Data Analysis"),
        ("S", "Geometry and Trigonometry"),
        ("INI", "Information and Ideas"),
        ("CAS", "Craft and Structure"),
        ("EOI", "Expression of Ideas"),
        ("SEC", "Standard English Conventions"),
    ]
    static let names: [String: String] = Dictionary(
        uniqueKeysWithValues: ordered.map { ($0.code, $0.name) }
    )
    /// 1...3, the same scale the self-rated confidence step uses.
    static let levelLabels = ["", "needs work", "growing", "strong"]
    static func displayLabel(_ level: Int) -> String {
        guard (1...3).contains(level) else { return "" }
        return levelLabels[level].capitalized
    }
}

final class StudyPlanGenerationService: Sendable {
    static let shared = StudyPlanGenerationService()
    private init() {}

    // MARK: - Screenshot score extraction (vision)

    func extractScores(from image: UIImage) async throws -> ExtractedScores {
        guard let dataURL = Self.jpegDataURL(image) else {
            throw StudyPlanGenerationError.badResponse
        }
        let system = """
        You read SAT practice score reports (College Board, Bluebook, Khan Academy and similar). \
        Extract the section scores AND the per-domain performance breakdown. Respond with ONLY a \
        single valid JSON object, no code fences:
        { "mathScore": number or null, "rwScore": number or null, "domains": [ { "code": "H", "level": 2 } ] }
        mathScore is the Math section score (200-800). rwScore is the Reading and Writing \
        section score (200-800). If the report shows only a total score out of 1600, split it \
        evenly. If you can't find a score, use null.
        "domains" is the Knowledge and Skills / performance-by-category breakdown these reports \
        show under the scores. Use these codes only:
        H = Algebra, P = Advanced Math, Q = Problem-Solving and Data Analysis, \
        S = Geometry and Trigonometry, INI = Information and Ideas, CAS = Craft and Structure, \
        EOI = Expression of Ideas, SEC = Standard English Conventions.
        level is 1, 2, or 3: 1 = weak (shown as "Needs work", an empty or nearly empty bar, or a \
        low percent correct), 2 = middling (shown as "Growing", a half-filled bar, or a middling \
        percent correct), 3 = strong (shown as "Strong", a full or nearly full bar, or a high \
        percent correct).
        Read the level off whatever the report actually shows: a written label, the fill of a bar, \
        a percent correct, or a raw correct-out-of-total. If the report shows percent correct, use \
        1 for under 60, 2 for 60 to 84, and 3 for 85 or more.
        Only include a domain you can actually see in this image. Never guess a level from the \
        section score alone. If the image has no breakdown at all, return an empty array.
        """
        let raw = try await KorahAIClient.shared.completeWithImage(
            system: system,
            userText: "Extract my section scores from this practice report.",
            imageDataURL: dataURL
        )
        guard let json = Self.parseJSONObject(raw) else {
            throw StudyPlanGenerationError.badResponse
        }
        return ExtractedScores(
            mathScore: Self.clampScore(json["mathScore"]),
            englishScore: Self.clampScore(json["rwScore"]),
            domains: Self.domainLevels(json["domains"])
        )
    }

    /// The model returns an array of {code, level}; everything downstream wants
    /// a map. Unknown codes and out-of-range levels are dropped rather than
    /// allowed to reach the plan prompt.
    private static func domainLevels(_ value: Any?) -> [String: Int] {
        guard let rows = value as? [[String: Any]] else { return [:] }
        var out: [String: Int] = [:]
        for row in rows {
            guard let code = (row["code"] as? String)?
                    .trimmingCharacters(in: .whitespaces).uppercased(),
                  StudyPlanDomains.names[code] != nil,
                  let level = row["level"] as? Int ?? (row["level"] as? Double).map(Int.init),
                  (1...3).contains(level)
            else { continue }
            out[code] = level
        }
        return out
    }

    private static func clampScore(_ value: Any?) -> Int? {
        guard let n = value as? Int ?? (value as? Double).map(Int.init) else { return nil }
        guard n >= 200, n <= 800 else { return nil }
        return (n / 10) * 10
    }

    private static func jpegDataURL(_ image: UIImage, maxDimension: CGFloat = 1500) -> String? {
        var target = image
        let largest = max(image.size.width, image.size.height)
        if largest > maxDimension {
            let scale = maxDimension / largest
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            target = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        }
        guard let data = target.jpegData(compressionQuality: 0.6) else { return nil }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    // MARK: - Plan generation

    func generatePlan(intake: StudyPlanIntake) async throws -> StudyPlan {
        let system = Self.systemPrompt
        let user = Self.userPrompt(intake: intake)

        let raw = try await KorahAIClient.shared.complete(
            messages: [
                AIChatMessage(role: "system", content: system),
                AIChatMessage(role: "user", content: user),
            ],
            temperature: 0.4,
            jsonResponse: true
        )
        guard let json = Self.parseJSONObject(raw) else {
            throw StudyPlanGenerationError.badResponse
        }
        return try Self.buildPlan(from: json, intake: intake)
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    You are Korah, a warm SAT coach who builds realistic study schedules. \
    Respond with ONLY a single valid JSON object, no code fences, no commentary:
    {
      "feedback": {
        "headline": "One encouraging sentence about the student's starting point.",
        "priorities": ["Up to 3 short bullets naming their biggest score levers"],
        "weeklyFocus": "One sentence on how the plan is structured week to week."
      },
      "sessions": [
        { "date": "yyyy-MM-dd", "start": "HH:mm", "durationMin": 45,
          "subject": "math" or "english", "skillName": "...", "activity": "..." }
      ]
    }
    Hard rules:
    - Sessions ONLY on the student's chosen study days, starting next occurrence of a chosen day, ending before the test date.
    - Total session minutes per week must roughly equal their weekly hours. Sessions are 30 to 90 minutes.
    - Start times between 15:30 and 20:00 unless weekends, where 09:00 to 20:00 is fine.
    - If the test is more than 10 weeks away, plan only the first 10 weeks.
    - skillName must be a real Digital SAT skill from the official domains (Algebra, Advanced Math, Problem-Solving and Data Analysis, Geometry and Trigonometry, Information and Ideas, Craft and Structure, Expression of Ideas, Standard English Conventions).
    - Domain levels arrive in words. "needs work" and "shaky" mean weak, "growing" and "okay" mean middling, "strong" means strong.
    - You will often get levels for only some of the eight domains, because a score report may only show part of the breakdown. Work with whatever you are given. Never drop a domain just because you have no data on it, and never fall back to giving everything equal time just because the data is incomplete.
    - Settle every domain into weak, middling, or strong using the best evidence you have for that specific domain, in this order: a measured level from their score report, then their self-rating, then their score for that domain's section (under 600 is weak, 600 to 699 is middling, 700 or above is strong), then middling if you have nothing at all.
    - A level you were given outranks one you inferred, so when two domains look equally weak, spend the time on the one you have real data on.
    - Weight time by those levels. Each week, spend about 55% of total minutes on weak domains, about 30% on middling ones, and about 15% on strong ones. A weak domain should get roughly three times the minutes of a strong one.
    - Never spread time evenly across all eight domains. Within a tier, split time evenly between the domains in that tier.
    - Strong domains still get a hard floor: at least one short review session every two weeks, so they don't decay.
    - Name the weak domains in feedback.priorities so the student knows why the plan looks the way it does.
    - activity is one short concrete line, e.g. "Practice set: 10 linear function questions" or "Timed reading drill: inferences".
    - Vary activities: practice sets, timed drills, review of missed questions, one full-length practice test roughly every 3 weeks (on a weekend day, 120 min is allowed for these only).
    - feedback is short and encouraging. Never use em dashes anywhere. Use contractions. Talk to "you".
    """

    private static func userPrompt(intake: StudyPlanIntake) -> String {
        var lines: [String] = []
        lines.append("Today's date: \(StudyPlanDates.dayString(Date()))")
        lines.append("Test date: \(StudyPlanDates.dayString(intake.testDate))")
        lines.append("Study days: \(intake.studyDays.joined(separator: ", "))")
        lines.append("Hours per week: \(intake.hoursPerWeek)")

        switch intake.source {
        case "sat":
            lines.append("Starting point: took the real SAT.")
        case "practice":
            lines.append("Starting point: took a practice test.")
        default:
            lines.append("Starting point: hasn't taken the SAT or a practice test yet.")
        }
        if let math = intake.mathScore {
            lines.append("Math score: \(math)")
        }
        if let english = intake.englishScore {
            lines.append("Reading and Writing score: \(english)")
        }
        // Measured performance from the score report. Stated before the
        // self-rating and marked as measured, because the plan should trust it
        // over a guess.
        if !intake.domainPerformance.isEmpty {
            let described = StudyPlanDomains.ordered.compactMap { code, name -> String? in
                guard let level = intake.domainPerformance[code], (1...3).contains(level) else { return nil }
                return "\(name): \(StudyPlanDomains.levelLabels[level])"
            }
            if !described.isEmpty {
                lines.append("Measured performance per domain, read from their score report: "
                             + described.joined(separator: "; "))
                // Named explicitly so a domain missing from the list reads as
                // "the report didn't show it" rather than "it was left out
                // because it's fine".
                let unread = StudyPlanDomains.ordered.compactMap { code, name -> String? in
                    if let level = intake.domainPerformance[code], (1...3).contains(level) { return nil }
                    return name
                }
                if !unread.isEmpty {
                    lines.append("Their report did not show these domains, so infer those levels yourself: "
                                 + unread.joined(separator: "; "))
                }
                lines.append("Treat the measured levels as the truth about what they struggle with, and budget time against them.")
            }
        }
        if !intake.confidence.isEmpty {
            let levels = ["", "shaky", "okay", "strong"]
            let described = intake.confidence
                .sorted { $0.key < $1.key }
                .compactMap { code, level -> String? in
                    guard let name = StudyPlanDomains.names[code], (1...3).contains(level) else { return nil }
                    return "\(name): \(levels[level])"
                }
            if !described.isEmpty {
                lines.append("Self-rated confidence per domain: " + described.joined(separator: "; "))
            }
        }
        if !intake.focusRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("What the student wants from the plan: \(intake.focusRequest)")
        }
        lines.append("Build my study plan.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Parse + validate

    private static func parseJSONObject(_ raw: String) -> [String: Any]? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func buildPlan(from json: [String: Any], intake: StudyPlanIntake) throws -> StudyPlan {
        var feedback = StudyPlanFeedback()
        if let fb = json["feedback"] as? [String: Any] {
            feedback.headline = (fb["headline"] as? String) ?? ""
            feedback.priorities = Array(((fb["priorities"] as? [String]) ?? []).prefix(3))
            feedback.weeklyFocus = (fb["weeklyFocus"] as? String) ?? ""
        }

        let today = Calendar.current.startOfDay(for: Date())
        let testDay = Calendar.current.startOfDay(for: intake.testDate)
        let allowedDays = Set(intake.studyDays)

        let rawSessions = (json["sessions"] as? [[String: Any]]) ?? []
        var sessions: [StudyPlanSession] = rawSessions.compactMap { s in
            guard let dateStr = s["date"] as? String,
                  let date = StudyPlanDates.date(from: dateStr),
                  date >= today, date < testDay,
                  allowedDays.contains(StudyPlanDates.dayKey(date)),
                  let start = s["start"] as? String,
                  start.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil,
                  let skillName = s["skillName"] as? String, !skillName.isEmpty,
                  let activity = s["activity"] as? String, !activity.isEmpty
            else { return nil }
            let duration = (s["durationMin"] as? Int)
                ?? (s["durationMin"] as? Double).map(Int.init) ?? 45
            let subject = (s["subject"] as? String) == "math" ? "math" : "english"
            return StudyPlanSession(
                date: dateStr,
                start: start,
                durationMin: min(max(duration, 20), 150),
                subject: subject,
                skillName: skillName,
                activity: activity
            )
        }
        sessions.sort { ($0.date, $0.start) < ($1.date, $1.start) }
        guard !sessions.isEmpty else { throw StudyPlanGenerationError.noSessions }

        return StudyPlan(
            testDate: StudyPlanDates.dayString(intake.testDate),
            studyDays: intake.studyDays,
            hoursPerWeek: intake.hoursPerWeek,
            source: intake.source,
            feedback: feedback,
            sessions: sessions
        )
    }
}
