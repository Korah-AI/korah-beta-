import Foundation
import FirebaseFirestore

// MARK: - SAT step-by-step explanation — global Firestore cache + Gemini generation.
// Mirrors the web's Ask Korah "Explanation" tab (sat/questions.html):
// satExplanations/{questionId} is a GLOBAL collection — the first user to view
// a question pays the AI cost; everyone else reads the cached steps.

@MainActor
final class SATExplanationService {

    static let shared = SATExplanationService()
    private init() {}

    private var db: Firestore { Firestore.firestore() }
    private var memoryCache: [String: SATExplanation] = [:]

    func explanation(for question: SATQuestion) async throws -> SATExplanation {
        let id = question.detailKey.isEmpty ? question.id : question.detailKey

        // 1. In-memory hit
        if let cached = memoryCache[id] { return cached }

        // 2. Firestore global cache
        if let cached = try? await readCache(id: id), !cached.steps.isEmpty {
            memoryCache[id] = cached
            return cached
        }

        // 3. Generate via /api/r, then write back (first-user-pays)
        let generated = try await generate(question: question)
        memoryCache[id] = generated
        try? await writeCache(id: id, explanation: generated, questionStem: question.stem)
        return generated
    }

    // MARK: - Firestore cache

    private func readCache(id: String) async throws -> SATExplanation? {
        let snap = try await db.collection("satExplanations").document(id).getDocument()
        guard snap.exists else { return nil }
        return try? snap.data(as: SATExplanation.self)
    }

    private func writeCache(id: String, explanation: SATExplanation, questionStem: String) async throws {
        let steps = explanation.steps.map { ["title": $0.title, "body": $0.body] }
        try await db.collection("satExplanations").document(id).setData([
            "answer": explanation.answer ?? "",
            "summary": explanation.summary ?? "",
            "steps": steps,
            "model": APIConfig.chatModel,
            "questionStem": String(questionStem.prefix(500)),
            "createdAt": ISO8601DateFormatter.satShared.string(from: Date()),
        ], merge: true)
    }

    // MARK: - Generation (prompt mirrors web buildExplanationSystemPrompt)

    private func systemPrompt() -> String {
        """
        You are Korah, an SAT tutor generating a step-by-step worked explanation for a single SAT question.

        OUTPUT FORMAT — output ONLY a raw JSON object, no code fences, no commentary:

        {
          "answer": "A|B|C|D or numeric string",
          "summary": "one-sentence takeaway",
          "steps": [
            { "title": "Step 1 — short label", "body": "markdown + KaTeX explanation of this step" },
            { "title": "Step 2 — short label", "body": "..." }
          ]
        }

        RULES:
        - 3 to 6 steps. Each step body is concise (1–4 sentences). Use KaTeX ($inline$ or $$display$$) for every variable, coefficient, and equation.
        - The first step restates the problem in your own words. The final step states the answer clearly.
        - Use Markdown (**bold**, *italic*, lists) inside step bodies if helpful.
        - Do NOT wrap the JSON in code fences. Do NOT add prose before or after the JSON.
        - If the question is ambiguous or the correct answer is not provided, still produce your best step-by-step solution.
        """
    }

    /// Plain-text context block (HTML stripped) matching the web's
    /// buildQuestionContextBlock.
    func contextBlock(for question: SATQuestion) -> String {
        var lines: [String] = []
        lines.append("Section: SAT \(question.section == "math" ? "Math" : "Reading & Writing")")
        if !question.domain.isEmpty { lines.append("Domain: \(question.domain)") }
        let passage = question.paragraph.strippingHTML()
        if !passage.isEmpty { lines.append("Passage:\n\(passage)") }
        lines.append("Question:\n\(question.stem.strippingHTML())")
        if !question.options.isEmpty {
            lines.append("Choices:")
            for option in question.options {
                lines.append("  \(option.key)) \(option.text.strippingHTML())")
            }
        }
        if !question.correctAnswer.isEmpty {
            lines.append("Correct answer: \(question.correctAnswer)")
        }
        return lines.joined(separator: "\n")
    }

    private func generate(question: SATQuestion) async throws -> SATExplanation {
        let user = "Generate the step-by-step explanation for this SAT question.\n\n" + contextBlock(for: question)
        let raw = try await KorahAIClient.shared.complete(
            messages: [
                AIChatMessage(role: "system", content: systemPrompt()),
                AIChatMessage(role: "user", content: user),
            ],
            temperature: 0.2,
            jsonResponse: true
        )
        if let parsed = Self.parseExplanationJSON(raw) { return parsed }
        // Fallback: wrap raw text in a single step so the user still gets something.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20 else { throw KorahAIError.emptyResponse }
        return SATExplanation(
            steps: [SATStep(title: "Explanation", body: trimmed)],
            answer: question.correctAnswer.isEmpty ? nil : question.correctAnswer,
            summary: nil, model: APIConfig.chatModel, createdAt: nil
        )
    }

    /// Tolerant JSON extraction: strips code fences, finds the first balanced
    /// object, and re-escapes stray LaTeX backslashes (mirrors the web parser).
    static func parseExplanationJSON(_ raw: String) -> SATExplanation? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let braceIndex = s.firstIndex(of: "{") else { return nil }
        s = String(s[braceIndex...])

        if let parsed = decode(s) { return parsed }

        // Repair single backslashes that aren't valid JSON escapes (\frac → \\frac)
        let repaired = repairLatexEscapes(in: s)
        if let parsed = decode(repaired) { return parsed }

        // Balanced-brace fallback
        if let chunk = firstBalancedObject(in: s) {
            if let parsed = decode(chunk) { return parsed }
            if let parsed = decode(repairLatexEscapes(in: chunk)) { return parsed }
        }
        return nil
    }

    private static func decode(_ s: String) -> SATExplanation? {
        guard let data = s.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(SATExplanation.self, from: data),
              !parsed.steps.isEmpty else { return nil }
        return parsed
    }

    private static func repairLatexEscapes(in s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var inString = false
        var previousWasBackslash = false
        var iterator = s.makeIterator()
        var pending: Character?

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let ch = next() {
            if previousWasBackslash {
                previousWasBackslash = false
                if inString {
                    let validEscapes: Set<Character> = ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]
                    if validEscapes.contains(ch) {
                        out.append("\\")
                        out.append(ch)
                    } else {
                        out.append("\\\\")
                        out.append(ch)
                    }
                } else {
                    out.append("\\")
                    out.append(ch)
                }
                continue
            }
            if ch == "\\" {
                previousWasBackslash = true
                continue
            }
            if ch == "\"" { inString.toggle() }
            out.append(ch)
        }
        if previousWasBackslash { out.append("\\") }
        return out
    }

    private static func firstBalancedObject(in s: String) -> String? {
        var depth = 0
        var inString = false
        var escaped = false
        for (offset, ch) in s.enumerated() {
            if escaped { escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let end = s.index(s.startIndex, offsetBy: offset)
                    return String(s[...end])
                }
            }
        }
        return nil
    }
}

// MARK: - HTML → plain text helper

extension String {
    /// Strips tags and decodes common entities — for building AI prompt
    /// context from College Board HTML (NOT for rendering).
    func strippingHTML() -> String {
        var text = replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&nbsp;": " ", "&rsquo;": "'", "&lsquo;": "'",
            "&rdquo;": "\u{201D}", "&ldquo;": "\u{201C}", "&mdash;": "—", "&ndash;": "–",
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
