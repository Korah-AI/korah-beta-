import Foundation

// MARK: - AI study generation
// Mirrors the web's study-api.js: try POST /api/generate-study-item first
// (server-side prompts, its own rate limit), fall back to the /api/r chat
// proxy with a JSON-schema prompt on non-429 failure.

enum StudyGenerationError: LocalizedError {
    case rateLimited(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .rateLimited(let message): return message
        case .failed(let message): return message
        }
    }
}

struct GeneratedPracticeQuestion {
    let type: String        // "mcq" | "openEnded"
    let text: String
    let options: [String]
    let answer: String
    let explanation: String
}

final class StudyGenerationService: Sendable {
    static let shared = StudyGenerationService()
    private init() {}

    // MARK: - Public API

    /// Returns (front, back) pairs.
    func generateFlashcards(prompt: String, title: String) async throws -> [(front: String, back: String)] {
        let content = try await generate(type: "flashcards", prompt: prompt, title: title)
        guard let cards = content["cards"] as? [[String: Any]] else {
            throw StudyGenerationError.failed("No flashcards in response")
        }
        let pairs = cards.compactMap { card -> (String, String)? in
            let front = (card["front"] as? String) ?? (card["term"] as? String) ?? ""
            let back = (card["back"] as? String) ?? (card["definition"] as? String) ?? ""
            guard !front.isEmpty, !back.isEmpty else { return nil }
            return (front, back)
        }
        guard !pairs.isEmpty else { throw StudyGenerationError.failed("No valid flashcards generated") }
        return pairs
    }

    /// Returns (title, markdown).
    func generateStudyGuide(prompt: String, title: String) async throws -> (title: String, markdown: String) {
        let content = try await generate(type: "studyGuide", prompt: prompt, title: title)
        let markdown = (content["markdown"] as? String) ?? ""
        guard !markdown.isEmpty else { throw StudyGenerationError.failed("Empty study guide") }
        let resolvedTitle = (content["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? title
        return (resolvedTitle, markdown)
    }

    func generatePracticeTest(prompt: String, title: String,
                              totalQuestions: Int = 10, mcqCount: Int? = nil) async throws -> [GeneratedPracticeQuestion] {
        let testConfig: [String: Any] = [
            "totalQuestions": totalQuestions,
            "mcqCount": mcqCount ?? Int((Double(totalQuestions) * 0.6).rounded()),
        ]
        let content = try await generate(type: "practiceTest", prompt: prompt, title: title, testConfig: testConfig)
        guard let questions = content["questions"] as? [[String: Any]] else {
            throw StudyGenerationError.failed("No questions in response")
        }
        let parsed = questions.compactMap { q -> GeneratedPracticeQuestion? in
            guard let text = q["text"] as? String, !text.isEmpty else { return nil }
            let type = (q["type"] as? String) == "openEnded" ? "openEnded" : "mcq"
            return GeneratedPracticeQuestion(
                type: type,
                text: text,
                options: (q["options"] as? [String]) ?? [],
                answer: (q["answer"] as? String) ?? "",
                explanation: (q["explanation"] as? String) ?? ""
            )
        }
        guard !parsed.isEmpty else { throw StudyGenerationError.failed("No valid questions generated") }
        return parsed
    }

    // MARK: - Primary endpoint with fallback

    private func generate(type: String, prompt: String, title: String,
                          testConfig: [String: Any]? = nil) async throws -> [String: Any] {
        do {
            return try await callGenerateEndpoint(type: type, prompt: prompt, title: title, testConfig: testConfig)
        } catch StudyGenerationError.rateLimited(let message) {
            throw StudyGenerationError.rateLimited(message)
        } catch {
            // Non-429 failure → fall back to the chat proxy (mirrors study-api.js)
            return try await fallbackViaChat(type: type, prompt: prompt, title: title, testConfig: testConfig)
        }
    }

    private func callGenerateEndpoint(type: String, prompt: String, title: String,
                                      testConfig: [String: Any]?) async throws -> [String: Any] {
        guard let url = URL(string: APIConfig.generateStudyItemURL) else {
            throw StudyGenerationError.failed("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        request.timeoutInterval = 300

        var body: [String: Any] = ["type": type, "prompt": prompt, "title": title]
        if let testConfig { body["testConfig"] = testConfig }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudyGenerationError.failed("No response")
        }
        if http.statusCode == 429 {
            throw StudyGenerationError.rateLimited("You've reached the study generation limit. Try again in a few minutes.")
        }
        guard (200...299).contains(http.statusCode) else {
            throw StudyGenerationError.failed("Generation failed (\(http.statusCode))")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [String: Any] else {
            throw StudyGenerationError.failed("Unexpected response shape")
        }
        return content
    }

    // MARK: - /api/r fallback

    private func fallbackViaChat(type: String, prompt: String, title: String,
                                 testConfig: [String: Any]?) async throws -> [String: Any] {
        let systemPrompt: String
        switch type {
        case "studyGuide":
            systemPrompt = """
            You are a study assistant. Generate a comprehensive study guide in Markdown \
            (headings, bullet points, bold). Use \\(...\\) for inline math and $$...$$ for display math. \
            Respond with ONLY the markdown, starting with an H1 title line.
            """
        case "practiceTest":
            let total = (testConfig?["totalQuestions"] as? Int) ?? 10
            systemPrompt = """
            You are a study assistant. Generate a practice test as ONLY a single valid JSON object:
            { "questions": [ { "type": "mcq" | "openEnded", "text": "...", "options": ["A","B","C","D"], "answer": "...", "explanation": "..." } ] }
            Generate \(total) questions (~60% mcq with exactly 4 options, rest openEnded with empty options array). No code fences.
            """
        default:
            systemPrompt = """
            You are a study assistant. Generate flashcards as ONLY a single valid JSON object:
            { "cards": [ { "front": "term or question", "back": "definition or answer" } ] }
            Create 15-20 clear, concise cards. No code fences.
            """
        }

        let user = "Title: \(title)\n\n\(prompt)"
        let raw = try await KorahAIClient.shared.complete(
            messages: [
                AIChatMessage(role: "system", content: systemPrompt),
                AIChatMessage(role: "user", content: user),
            ],
            temperature: 0.6,
            jsonResponse: type != "studyGuide"
        )

        if type == "studyGuide" {
            var markdown = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            var resolvedTitle = title
            if let match = markdown.range(of: "^#\\s+(.+)$", options: .regularExpression) {
                resolvedTitle = String(markdown[match]).replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespaces)
                markdown.removeSubrange(match)
                markdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ["title": resolvedTitle, "markdown": markdown]
        }

        // JSON types: tolerate leading/trailing junk
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StudyGenerationError.failed("Could not parse AI response")
        }
        return json
    }
}
