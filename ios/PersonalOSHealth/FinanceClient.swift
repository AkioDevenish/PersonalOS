import Foundation

/// The money ledger.
struct FinanceClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

    struct Entry: Decodable, Identifiable, Hashable {
        let id: String
        let date: Double
        /// Signed minor units.
        let minor: Int
        let currency: String
        let category: String
        let note: String
        let source: String

        var spent: Bool { minor < 0 }
        var when: Date { Date(timeIntervalSince1970: date / 1000) }
        /// Typed in by hand, as opposed to arriving from a connected account.
        var byHand: Bool { source == "manual" }
    }

    struct Total: Decodable, Hashable {
        let currency: String
        let incoming: Int
        let outgoing: Int
        let net: Int

        // "in" and "out" are the server's words; "in" is not available as a Swift name.
        enum CodingKeys: String, CodingKey {
            case currency, net
            case incoming = "in"
            case outgoing = "out"
        }
    }

    struct CategorySpend: Decodable, Hashable, Identifiable {
        let category: String
        let currency: String
        let minor: Int

        var id: String { currency + "/" + category }
    }

    struct Ledger: Decodable {
        let entries: [Entry]
        let totals: [Total]
        let spendByCategory: [CategorySpend]

        static let empty = Ledger(entries: [], totals: [], spendByCategory: [])
    }

    func ledger(from: Date, to: Date) async throws -> Ledger {
        let a = Int(from.timeIntervalSince1970 * 1000)
        let b = Int(to.timeIntervalSince1970 * 1000)
        let data = try await transport.query("finance:ledger", ["from": a, "to": b])
        return try JSONDecoder().decode(Ledger.self, from: data)
    }

    func add(
        date: Date,
        minor: Int,
        currency: String,
        category: String,
        note: String?
    ) async throws {
        var body: [String: Any] = [
            "date": Int(date.timeIntervalSince1970 * 1000),
            "minor": minor,
            "currency": currency,
            "category": category,
        ]
        if let note, !note.isEmpty { body["note"] = note }
        _ = try await transport.mutation("finance:add", body)
    }

    func remove(id: String) async throws {
        _ = try await transport.mutation("finance:remove", ["id": id])
    }
}

/// Turning integer minor units into something a person reads, and back.
enum Money {
    /// The currency this phone is set up for, falling back to US dollars only when the locale names
    /// none.
    static var deviceDefault: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// How many minor units make a major one, for this currency.
    static func fractionDigits(_ currency: String) -> Int {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.maximumFractionDigits
    }

    private static func divisor(_ currency: String) -> Double {
        pow(10.0, Double(fractionDigits(currency)))
    }

    /// "$12.30", in the reader's locale conventions but the entry's currency.
    static func text(_ minor: Int, _ currency: String, showingSign: Bool = false) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        let major = Double(minor) / divisor(currency)
        // The sign is carried by the words around the figure on most screens, so it is shown only
        // where a row could be either.
        let shown = showingSign ? major : abs(major)
        return f.string(from: NSNumber(value: shown)) ?? String(format: "%.2f", shown)
    }

    /// Minor units as a bare major-unit number, for a text field.
    static func major(_ minor: Int, _ currency: String) -> String {
        let digits = fractionDigits(currency)
        let value = Double(minor) / pow(10.0, Double(digits))
        return String(format: "%.\(digits)f", value)
    }

    /// What someone typed, as whole minor units.
    static func minor(from text: String, currency: String) -> Int? {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let major = Double(cleaned), major.isFinite else { return nil }
        return Int((major * divisor(currency)).rounded())
    }
}
