import Foundation

/// Talking to a person.
struct ConsultClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

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
        let data = try await transport.send("/api/well-being/consult", method: "GET", body: nil)
        return try JSONDecoder().decode(Inbox.self, from: data)
    }

    func thread(id: String) async throws -> Thread {
        let data = try await transport.send("/api/well-being/consult?id=\(id)", method: "GET", body: nil)
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
        let data = try await transport.send("/api/well-being/consult", method: "POST", body: body)
        return (try? JSONDecoder().decode(Started.self, from: data))?.id ?? ""
    }

    func reply(id: String, body text: String) async throws {
        _ = try await transport.send(
            "/api/well-being/consult", method: "POST", body: ["id": id, "body": text]
        )
    }

}
