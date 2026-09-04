import Foundation

/// The time ledger. The money one's twin, deliberately.
struct TimeClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

    struct Block: Decodable, Identifiable, Hashable {
        let id: String
        let start: Double
        let minutes: Int
        let activity: String
        let category: String
        let note: String
        let source: String

        var began: Date { Date(timeIntervalSince1970: start / 1000) }
        var byHand: Bool { source == "manual" }
    }

    struct CategoryTime: Decodable, Hashable, Identifiable {
        let category: String
        let minutes: Int

        var id: String { category }
    }

    struct Ledger: Decodable {
        let blocks: [Block]
        let totalMinutes: Int
        let byCategory: [CategoryTime]

        static let empty = Ledger(blocks: [], totalMinutes: 0, byCategory: [])
    }

    func ledger(from: Date, to: Date) async throws -> Ledger {
        let a = Int(from.timeIntervalSince1970 * 1000)
        let b = Int(to.timeIntervalSince1970 * 1000)
        let data = try await transport.send("/api/time?from=\(a)&to=\(b)", method: "GET", body: nil)
        return try JSONDecoder().decode(Ledger.self, from: data)
    }

    func add(
        start: Date,
        minutes: Int,
        activity: String,
        category: String,
        note: String?
    ) async throws {
        var body: [String: Any] = [
            "start": Int(start.timeIntervalSince1970 * 1000),
            "minutes": minutes,
            "activity": activity,
            "category": category,
        ]
        if let note, !note.isEmpty { body["note"] = note }
        _ = try await transport.send("/api/time", method: "POST", body: body)
    }

    func remove(id: String) async throws {
        _ = try await transport.send("/api/time?id=\(id)", method: "DELETE", body: nil)
    }
}

/// Durations in words.
enum Duration {
    /// "1h 25m", "45m", "3h".
    ///
    /// The bare hour drops its minutes rather than reading "3h 0m", which is a
    /// machine's way of saying three hours.
    static func text(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// The same span for a heading, where hours alone read better.
    static func hours(_ minutes: Int) -> String {
        let h = Double(minutes) / 60
        return h < 10
            ? String(format: "%.1f", h).replacingOccurrences(of: ".0", with: "")
            : String(Int(h.rounded()))
    }
}
