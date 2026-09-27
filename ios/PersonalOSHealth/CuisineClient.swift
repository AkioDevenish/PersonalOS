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
        /// Vouched for by nobody: either written down for the country, or a
        /// model's guess. `written` tells the two apart.
        let seeded: Bool
        /// Written down for this country, and therefore in everyone's
        /// suggestions without needing a single vote.
        let written: Bool
        /// Produced by the model on somebody's phone. Not in anyone's
        /// suggestions until people confirm it.
        let guessed: Bool
        /// Whether the caller is one of the people who named it.
        let mine: Bool

        var id: String { key }

        /// Whether one person saying so should be enough to remove it.
        ///
        /// True only for what nobody vouched for. A written-down dish is
        /// changed by editing the list; one enough people have named is
        /// settled, and not something a passer-by undoes.
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

    /// Straight to Convex. The route this replaced held no logic of its own:
    /// it read the query string and called the same three functions.
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
    ///
    /// Only works on what nobody vouched for — a model's guess, or one
    /// person's suggestion. The server refuses the rest.
    @discardableResult
    func reject(country: String, dish: String) async throws -> Bool {
        struct Result: Decodable { let rejected: Bool }
        let data = try await transport.mutation(
            "health/cuisine:reject", ["country": country, "dish": dish]
        )
        return (try? JSONDecoder().decode(Result.self, from: data))?.rejected ?? false
    }

    /// Writes the starter list for a country nobody has named anything for.
    ///
    /// Carries no votes: it is a first guess so the first person to choose a
    /// country isn't handed an empty vocabulary, and a seeded dish nobody
    /// actually eats stays at zero forever, which is the right fate for it.
    func seed(country: String, dishes: [String]) async throws {
        _ = try await transport.mutation(
            "health/cuisine:seed", ["country": country, "dishes": dishes]
        )
    }

}
