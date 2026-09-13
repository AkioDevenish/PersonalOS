import Foundation

/// Talks to the well-being routes that survived the web teardown: the meal
/// engine and the expert AI reports, both still served by the Mac.
///
/// These run Gemma locally through Ollama, so they only answer while that
/// machine is up — which is exactly why every call here surfaces a plain
/// reason rather than a spinner that never ends.
struct InsightsClient {
    /// Three minutes: a local model doing real work is not fast, and this is
    /// the only client that needs longer than the default.
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) {
        transport = Transport(auth: auth, timeout: 180)
    }

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
        let data = try await transport.get("/api/well-being/nutrition-ai")
        return (try? JSONDecoder().decode(HistoryResponse.self, from: data))?.history ?? []
    }

    /// Asks the engine for three new suggestions for the given moment, cooked
    /// where the person actually lives.
    func generateMeals(context: String, country: String?, dishes: [String] = []) async throws -> String {
        var body: [String: Any] = ["mealContext": context, "context": context]
        if let country { body["country"] = country }
        if !dishes.isEmpty { body["dishes"] = dishes }
        let data = try await transport.post("/api/well-being/nutrition-ai", body: body)
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
        let data = try await transport.get("/api/well-being/ai-reports?period=\(period)&expert=\(expert)")
        return (try? JSONDecoder().decode(ReportsResponse.self, from: data))?.reports ?? []
    }

    /// Triggers a fresh analysis. Slow — Gemma is doing real work.
    func generateReport(period: String, expert: String) async throws {
        _ = try await transport.post("/api/well-being/analyze",
                           body: ["period": period, "expert": expert, "force": true])
    }
}

/// Kept as a name, not as a second definition. Several screens catch
/// `InsightsError` by that name, and the vocabulary of failures is the same
/// everywhere: a bad URL, no session, a status code.
typealias InsightsError = TransportError
