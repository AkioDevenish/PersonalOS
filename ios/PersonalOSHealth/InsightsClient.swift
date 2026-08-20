import Foundation

/// Talks to the well-being routes that survived the web teardown: the meal
/// engine and the expert AI reports, both still served by the Mac.
///
/// These run Gemma locally through Ollama, so they only answer while that
/// machine is up — which is exactly why every call here surfaces a plain
/// reason rather than a spinner that never ends.
struct InsightsClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) { self.auth = auth }

    // MARK: Meals

    struct Recommendation: Decodable, Identifiable {
        let id: Int
        let meal_context: String?
        let meal_names: String?
        let insight: String?
        let created_at: String?

        /// The engine stores names as one delimited string.
        var meals: [String] {
            (meal_names ?? "")
                .components(separatedBy: CharacterSet(charactersIn: ",|\n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }

    private struct HistoryResponse: Decodable {
        let success: Bool?
        let history: [Recommendation]?
    }

    func mealHistory() async throws -> [Recommendation] {
        let data = try await get("/api/well-being/nutrition-ai")
        return (try? JSONDecoder().decode(HistoryResponse.self, from: data))?.history ?? []
    }

    /// Asks the engine for three new suggestions for the given moment, cooked
    /// where the person actually lives.
    func generateMeals(context: String, country: String?, dishes: [String] = []) async throws -> String {
        var body: [String: Any] = ["mealContext": context, "context": context]
        if let country { body["country"] = country }
        if !dishes.isEmpty { body["dishes"] = dishes }
        let data = try await post("/api/well-being/nutrition-ai", body: body)
        // The route streams prose; take whatever text field it lands in.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["recommendation", "text", "result", "message"] {
                if let s = obj[key] as? String, !s.isEmpty { return s }
            }
            if let err = obj["error"] as? String { throw InsightsError.server(err) }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: Expert reports

    struct Report: Decodable, Identifiable {
        let id: Int
        let period: String?
        let report_text: String?
        let created_at: String?
        let expert: String?
    }

    private struct ReportsResponse: Decodable { let reports: [Report]? }

    func reports(period: String, expert: String) async throws -> [Report] {
        let data = try await get("/api/well-being/ai-reports?period=\(period)&expert=\(expert)")
        return (try? JSONDecoder().decode(ReportsResponse.self, from: data))?.reports ?? []
    }

    /// Triggers a fresh analysis. Slow — Gemma is doing real work.
    func generateReport(period: String, expert: String) async throws {
        _ = try await post("/api/well-being/analyze",
                           body: ["period": period, "expert": expert, "force": true])
    }

    // MARK: Transport

    private func request(_ path: String, method: String, body: [String: Any]?) async throws -> URLRequest {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw InsightsError.badURL }
        guard let token = await auth.currentToken() else { throw InsightsError.notSignedIn }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 180   // local model inference is not fast
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    private func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw InsightsError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw InsightsError.http(http.statusCode, body)
        }
        return data
    }

    private func get(_ path: String) async throws -> Data {
        try await send(request(path, method: "GET", body: nil))
    }

    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        try await send(request(path, method: "POST", body: body))
    }
}

enum InsightsError: LocalizedError {
    case badURL, badResponse, notSignedIn
    case http(Int, String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .badResponse: return "Unexpected server response"
        case .notSignedIn: return "Sign in to use insights"
        case .server(let m): return m
        case .http(let code, _):
            // The engine lives on the Mac; when it's off, say so plainly.
            if code == 500 { return "The insight engine didn't answer. Is the Mac awake with Ollama running?" }
            if code == 401 { return "Your session expired. Sign in again" }
            return "Request failed (\(code))"
        }
    }
}
