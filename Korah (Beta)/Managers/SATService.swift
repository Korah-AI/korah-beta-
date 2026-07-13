import Foundation

// MARK: - SAT Bank API client
// GET /api/sat/q|qi|s on the canonical Korah deployment.
// Public, CDN-cached — no auth token required.

enum SATServiceError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid SAT API URL."
        case .badStatus(let code):
            return code == 502
                ? "Could not reach the College Board question bank."
                : "SAT bank error (\(code))."
        case .emptyResponse: return "The question bank returned no data."
        }
    }
}

struct SATQuery {
    var sections: Set<String> = []          // empty = any
    var domains: Set<String> = []           // domain NAMES (e.g. "Algebra"); empty = any
    var skills: Set<String> = []            // skill codes; empty = any
    var difficulties: Set<String> = []      // E/M/H; empty = any
    var assessment: String = "SAT"
    var limit: Int? = nil                   // nil = all matching
    var random: Bool = false
    var questionIds: [String] = []          // explicit ids (review missed / saved)
}

final class SATService: Sendable {
    static let shared = SATService()
    private init() {}

    private var session: URLSession { .shared }

    // MARK: - Question list

    func fetchQuestions(_ query: SATQuery) async throws -> SATQuestionListResponse {
        var components = URLComponents(string: APIConfig.satQuestionsURL)
        var items: [URLQueryItem] = []

        if !query.questionIds.isEmpty {
            items.append(URLQueryItem(name: "questionIds", value: query.questionIds.joined(separator: ",")))
        } else {
            let sectionValue = query.sections.isEmpty || query.sections.count == 2
                ? "any" : query.sections.sorted().joined(separator: ",")
            items.append(URLQueryItem(name: "sections", value: sectionValue))
            items.append(URLQueryItem(name: "domains",
                                      value: query.domains.isEmpty ? "any" : query.domains.sorted().joined(separator: ",")))
            items.append(URLQueryItem(name: "skills",
                                      value: query.skills.isEmpty ? "any" : query.skills.sorted().joined(separator: ",")))
            if !query.difficulties.isEmpty {
                items.append(URLQueryItem(name: "difficulties", value: query.difficulties.sorted().joined(separator: ",")))
            }
        }
        if query.assessment != "SAT" {
            items.append(URLQueryItem(name: "assessment", value: query.assessment))
        }
        if let limit = query.limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        components?.queryItems = items

        guard let url = components?.url else { throw SATServiceError.invalidURL }
        let data = try await get(url)
        var response = try JSONDecoder().decode(SATQuestionListResponse.self, from: data)
        if query.random, response.questions.count > 1 {
            response = SATQuestionListResponse(
                batchSize: response.batchSize,
                count: response.count,
                questions: response.questions.shuffled()
            )
        }
        return response
    }

    // MARK: - Question detail (lazy hydration)

    func fetchDetail(id: String) async throws -> SATQuestionDetail {
        var components = URLComponents(string: APIConfig.satQuestionDetailURL)
        components?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components?.url else { throw SATServiceError.invalidURL }
        let data = try await get(url)
        return try JSONDecoder().decode(SATQuestionDetail.self, from: data)
    }

    // MARK: - Bank stats

    func fetchStats(assessment: String = "SAT") async throws -> SATBankStats {
        var components = URLComponents(string: APIConfig.satStatsURL)
        if assessment != "SAT" {
            components?.queryItems = [URLQueryItem(name: "assessment", value: assessment)]
        }
        guard let url = components?.url else { throw SATServiceError.invalidURL }
        let data = try await get(url)
        return try JSONDecoder().decode(SATStatsResponse.self, from: data).data
    }

    // MARK: - Shared GET

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 45
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SATServiceError.emptyResponse }
        guard (200...299).contains(http.statusCode) else { throw SATServiceError.badStatus(http.statusCode) }
        return data
    }
}
