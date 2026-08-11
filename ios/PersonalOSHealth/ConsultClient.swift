import Foundation

/// Talking to a person.
struct ConsultClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) { self.auth = auth }

    struct Summary: Decodable, Identifiable, Hashable {
        let id: String
        let topic: String
        let status: String          // waiting | answered | closed
        let created_at: Double
        let updated_at: Double
        let last_message: String
        let last_from: String
        let replies: Int

        var waiting: Bool { status == "waiting" }
    }

    struct Message: Decodable, Identifiable, Hashable {
        let id: String
        let from: String            // you | nutritionist
        let body: String
        let created_at: Double

        var fromProfessional: Bool { from == "nutritionist" }
    }

    struct Thread: Decodable {
        let id: String
        let topic: String
        let status: String
        let shared: String
        let created_at: Double
        let messages: [Message]
    }

    /// A nutritionist you can choose to ask.
    struct Professional: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let country: String         // ISO region code
        let credentials: String
        let bio: String
        let price_credits: Int

        /// The country in words — the thing you actually want to know before
        /// asking someone about food.
        var place: String { Cuisine.name(for: country) }

        var price: String {
            price_credits == 0
                ? "Free"
                : "\(price_credits) \(price_credits == 1 ? "credit" : "credits")"
        }
    }

    struct Inbox: Decodable {
        let consults: [Summary]
        /// Whether anyone is actually on the other end. The screen says so.
        let staffed: Bool
        let professionals: [Professional]

        static let empty = Inbox(consults: [], staffed: false, professionals: [])
    }

    func inbox() async throws -> Inbox {
        let data = try await send(try await request("/api/well-being/consult", method: "GET", body: nil))
        return try JSONDecoder().decode(Inbox.self, from: data)
    }

    func thread(id: String) async throws -> Thread {
        let data = try await send(try await request("/api/well-being/consult?id=\(id)", method: "GET", body: nil))
        return try JSONDecoder().decode(Thread.self, from: data)
    }

    /// Opens a consultation. `shared` is the readings text the person saw and
    /// agreed to hand over — sent as shown, so what the nutritionist reads is
    /// what was consented to.
    @discardableResult
    func start(
        topic: String,
        question: String,
        nutritionistId: String?,
        shared: String?,
        country: String?
    ) async throws -> String {
        struct Started: Decodable { let id: String }
        var body: [String: Any] = ["topic": topic, "question": question]
        if let nutritionistId, !nutritionistId.isEmpty { body["nutritionistId"] = nutritionistId }
        if let shared, !shared.isEmpty { body["shared"] = shared }
        if let country, !country.isEmpty { body["country"] = country }
        let data = try await send(try await request("/api/well-being/consult", method: "POST", body: body))
        return (try? JSONDecoder().decode(Started.self, from: data))?.id ?? ""
    }

    func reply(id: String, body text: String) async throws {
        _ = try await send(try await request(
            "/api/well-being/consult", method: "POST", body: ["id": id, "body": text]
        ))
    }

    // MARK: Transport

    private func request(_ path: String, method: String, body: [String: Any]?) async throws -> URLRequest {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw InsightsError.badURL }
        guard let token = await auth.currentToken() else { throw InsightsError.notSignedIn }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 30
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
            throw InsightsError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
