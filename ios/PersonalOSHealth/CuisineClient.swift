import Foundation

/// The shared list of what a country eats.
struct CuisineClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

    struct Dish: Decodable, Identifiable, Hashable {
        let key: String
        let dish: String
        let votes: Int
        /// On the written list for this country.
        let written: Bool
        let mine: Bool

        var id: String { key }

        /// Only dishes nobody has vouched for can be rejected.
        func canBeRejected(threshold: Int) -> Bool {
            !written && votes < threshold
        }
    }

    struct Book: Decodable {
        let threshold: Int
        let all: [Dish]
        /// What the prompt may cook from: everything vouched for, plus yours.
        let canon: [String]

        static let empty = Book(threshold: 3, all: [], canon: [])
    }

    /// Straight to Convex.
    func book(country: String) async throws -> Book {
        let data = try await transport.query("health/cuisine:forCountry", ["country": country])
        return try JSONDecoder().decode(Book.self, from: data)
    }

    /// Puts a dish forward, or takes your vote back if you already named it.
    @discardableResult
    func suggest(country: String, dish: String) async throws -> Bool {
        struct Result: Decodable { let added: Bool }
        let data = try await transport.mutation(
            "health/cuisine:suggest", ["country": country, "dish": dish]
        )
        return (try? JSONDecoder().decode(Result.self, from: data))?.added ?? false
    }

    /// Says a dish is not eaten in a country, or takes that back.
    @discardableResult
    func reject(country: String, dish: String) async throws -> Bool {
        struct Result: Decodable { let rejected: Bool }
        let data = try await transport.mutation(
            "health/cuisine:reject", ["country": country, "dish": dish]
        )
        return (try? JSONDecoder().decode(Result.self, from: data))?.rejected ?? false
    }
}
