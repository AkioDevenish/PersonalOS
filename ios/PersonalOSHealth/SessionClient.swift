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
        let data = try await transport.mutation("health/consult:openSession", body)
        return try JSONDecoder().decode(Opened.self, from: data)
    }

    func thread(id: String) async throws -> Thread {
        let data = try await transport.query("health/consult:thread", ["id": id])
        return try JSONDecoder().decode(Thread.self, from: data)
    }

    /// Raises a checkout and hands back the page to send the payer to.
    ///
    /// Throws `PaymentUnavailable` when no processor is connected, which is a
    /// different thing from a payment being refused and reads differently on
    /// screen.
    func startPayment(id: String) async throws -> URL {
        struct Raised: Decodable {
            let url: String?
            let paid: Bool?
            let error: String?
        }
        do {
            let data = try await transport.send(
                "/api/well-being/pay", method: "POST", body: ["id": id]
            )
            let raised = try JSONDecoder().decode(Raised.self, from: data)
            if raised.paid == true { throw PaymentUnavailable.alreadySettled }
            guard let link = raised.url, let url = URL(string: link) else {
                throw TransportError.badResponse
            }
            return url
        } catch TransportError.http(503, _) {
            throw PaymentUnavailable.noProcessor
        }
    }

    /// Asks the server, which asks the processor. The redirect back from a
    /// checkout page is not evidence and is never treated as any.
    func isPaid(id: String) async -> Bool {
        struct Settled: Decodable { let paid: Bool }
        guard let data = try? await transport.send(
            "/api/well-being/pay?id=\(id)", method: "GET", body: nil
        ) else { return false }
        return (try? JSONDecoder().decode(Settled.self, from: data))?.paid ?? false
    }

    // MARK: Signalling, for calls this app runs itself

    struct IceServer: Decodable {
        let urls: String
        let username: String?
        let credential: String?
    }

    struct IceConfig: Decodable {
        let servers: [IceServer]
        /// False when no relay is configured, which is worth surfacing: a
        /// fifth of calls need one and will otherwise fail without saying why.
        let relayAvailable: Bool
    }

    struct Signal: Decodable {
        let kind: String
        let payload: String
        let at: Double
    }

    func iceServers(id: String) async throws -> IceConfig {
        let data = try await transport.query("health/signal:iceServers")
        return try JSONDecoder().decode(IceConfig.self, from: data)
    }

    func signals(id: String, after: Double) async throws -> [Signal] {
        let data = try await transport.query("health/signal:since", ["id": id, "after": after])
        return try JSONDecoder().decode([Signal].self, from: data)
    }

    func postSignal(id: String, kind: String, payload: String) async throws {
        _ = try await transport.mutation(
            "health/signal:post", ["id": id, "kind": kind, "payload": payload]
        )
    }

    func clearSignals(id: String) async throws {
        _ = try await transport.mutation("health/signal:clear", ["id": id])
    }

    func send(id: String, body text: String) async throws {
        _ = try await transport.mutation("health/consult:send", ["id": id, "body": text])
    }
}


enum PaymentUnavailable: LocalizedError {
    case noProcessor
    case alreadySettled

    var errorDescription: String? {
        switch self {
        case .noProcessor:
            return "No payment processor is connected yet, so this cannot be collected."
        case .alreadySettled:
            return "This conversation is already paid for."
        }
    }
}


