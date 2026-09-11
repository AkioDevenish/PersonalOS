import Foundation

/// The shared list of what a country eats.
///
/// One vote each, and a dish becomes part of what the model is told to cook
/// from once enough people have named it. Your own suggestions count for you
/// straight away — waiting for strangers to agree before the app will cook
/// something you said you eat would be absurd.
struct CuisineClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

    struct Dish: Decodable, Identifiable, Hashable {
        let key: String
        let dish: String
        let votes: Int
        let seeded: Bool
        /// Whether the caller is one of the people who named it.
        let mine: Bool

        var id: String { key }
    }

    struct Book: Decodable {
        let threshold: Int
        let all: [Dish]
        /// What the prompt may cook from: everything vouched for, plus yours.
        let canon: [String]

        static let empty = Book(threshold: 3, all: [], canon: [])
    }

    func book(country: String) async throws -> Book {
        let data = try await transport.send(
            "/api/well-being/cuisine?country=\(country)", method: "GET", body: nil
        )
        return try JSONDecoder().decode(Book.self, from: data)
    }

    /// Puts a dish forward, or takes your vote back if you already named it.
    @discardableResult
    func suggest(country: String, dish: String) async throws -> Bool {
        struct Result: Decodable { let added: Bool }
        let data = try await transport.send(
            "/api/well-being/cuisine", method: "POST",
            body: ["country": country, "dish": dish]
        )
        return (try? JSONDecoder().decode(Result.self, from: data))?.added ?? false
    }

    /// Writes the starter list for a country nobody has named anything for.
    ///
    /// Carries no votes: it is a first guess so the first person to choose a
    /// country isn't handed an empty vocabulary, and a seeded dish nobody
    /// actually eats stays at zero forever, which is the right fate for it.
    func seed(country: String, dishes: [String]) async throws {
        _ = try await transport.send(
            "/api/well-being/cuisine", method: "POST",
            body: ["country": country, "dishes": dishes]
        )
    }

}
