import Foundation

/// One conversation with one specialist, written or on a call.
///
/// A call and a written exchange are the same relationship with the same
/// history, so they are one thing here with a `kind`, rather than two systems
/// that would each have to be consulted to show somebody what they have
/// already asked.
struct SessionClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

    enum Kind: String { case text, video }

    struct Opened: Decodable {
        let id: String
        let kind: String
        /// The agreed price in whole minor units, fixed at the moment of
        /// opening so a later change to the rate cannot rewrite what is owed.
        let price_minor: Int
        let currency: String
        /// "free", "pending" or "paid".
        let payment_status: String

        var free: Bool { payment_status == "free" }
        var owing: Bool { payment_status == "pending" }
        var price: String { Money.text(price_minor, currency) }
    }

    struct Message: Decodable, Identifiable, Hashable {
        let id: String
        let from: String            // you | nutritionist
        let body: String
        let created_at: Double

        var theirs: Bool { from != "you" }
        var at: Date { Date(timeIntervalSince1970: created_at / 1000) }
    }

    struct Thread: Decodable {
        let id: String
        let topic: String
        let status: String
        let messages: [Message]

        static let empty = Thread(id: "", topic: "", status: "", messages: [])
    }

    /// Opens the conversation, taking the fee if there is one.
    func open(specialistId: String, kind: Kind, topic: String?) async throws -> Opened {
        var body: [String: Any] = ["specialistId": specialistId, "kind": kind.rawValue]
        if let topic, !topic.isEmpty { body["topic"] = topic }
        let data = try await transport.send("/api/well-being/session", method: "POST", body: body)
        return try JSONDecoder().decode(Opened.self, from: data)
    }

    func thread(id: String) async throws -> Thread {
        let data = try await transport.send("/api/well-being/session?id=\(id)", method: "GET", body: nil)
        return try JSONDecoder().decode(Thread.self, from: data)
    }

    func send(id: String, body text: String) async throws {
        _ = try await transport.send(
            "/api/well-being/session", method: "POST", body: ["id": id, "body": text]
        )
    }
}
