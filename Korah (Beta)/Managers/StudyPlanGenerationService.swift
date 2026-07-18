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
        Extract the section scores. Respond with ONLY a single valid JSON object, no code fences:
        { "mathScore": number or null, "rwScore": number or null }
        mathScore is the Math section score (200-800). rwScore is the Reading and Writing \
        section score (200-800). If the report shows only a total score out of 1600, split it \
        evenly. If you can't find a score, use null.
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
            englishScore: Self.clampScore(json["rwScore"])
        )
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
    - Spend more time on the student's weakest areas, but keep at least a third of time maintaining strengths.
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
        if !intake.confidence.isEmpty {
            let names: [String: String] = [
                "H": "Algebra", "P": "Advanced Math",
                "Q": "Problem-Solving and Data Analysis", "S": "Geometry and Trigonometry",
                "INI": "Information and Ideas", "CAS": "Craft and Structure",
                "EOI": "Expression of Ideas", "SEC": "Standard English Conventions",
            ]
            let levels = ["", "shaky", "okay", "strong"]
            let described = intake.confidence
                .sorted { $0.key < $1.key }
                .compactMap { code, level -> String? in
                    guard let name = names[code], (1...3).contains(level) else { return nil }
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
