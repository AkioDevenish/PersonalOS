import Foundation
import Combine

/// Articles on the server: what is published, what an author has written, and
/// what is waiting for a reviewer.
///
/// Every rule that matters — who may write, what passes the checks, who may
/// approve — is enforced in convex/articles.ts. This only carries requests,
/// because a rule the app enforces is a rule an edited request skips.
struct ArticlesClient {
    private let transport = Transport()

    struct Abilities: Decodable {
        let canWrite: Bool
        let canReview: Bool
    }

    /// One of the author's own articles, in whatever state it is.
    struct Draft: Decodable, Identifiable, Hashable {
        let id: String
        let title: String
        let category: String
        let summary: String
        let body: String
        let symbol: String
        let colour: String
        let minutes: Int
        let status: String
        let flags: [String]
        let review_note: String?
        let updated_at: Double

        var statusText: String {
            switch status {
            case "submitted": return "Waiting for review"
            case "changes_requested": return "Changes requested"
            case "published": return "On Home"
            case "withdrawn": return "Withdrawn"
            default: return "Draft"
            }
        }
    }

    /// An article waiting for review, with what the automatic check noticed.
    struct Submission: Decodable, Identifiable, Hashable {
        let article: Article
        let flags: [String]
        let own: Bool
        var id: String { article.id }

        private enum Keys: String, CodingKey { case flags, own }

        init(from decoder: Decoder) throws {
            article = try Article(from: decoder)
            let c = try decoder.container(keyedBy: Keys.self)
            flags = try c.decode([String].self, forKey: .flags)
            own = try c.decode(Bool.self, forKey: .own)
        }
    }

    struct Saved: Decodable {
        let id: String
        let errors: [String]
        let flags: [String]
    }

    func published() async throws -> [Article] {
        try JSONDecoder().decode([Article].self, from: try await transport.query("articles:published"))
    }

    func abilities() async throws -> Abilities {
        try JSONDecoder().decode(Abilities.self, from: try await transport.query("articles:abilities"))
    }

    func mine() async throws -> [Draft] {
        try JSONDecoder().decode([Draft].self, from: try await transport.query("articles:mine"))
    }

    func save(id: String?, title: String, category: String, summary: String,
              body: String, symbol: String, colour: String) async throws -> Saved {
        var args: [String: Any] = [
            "title": title, "category": category, "summary": summary,
            "body": body, "symbol": symbol, "colour": colour,
        ]
        if let id { args["id"] = id }
        return try JSONDecoder().decode(Saved.self, from: try await transport.mutation("articles:save", args))
    }

    func submit(id: String) async throws {
        _ = try await transport.mutation("articles:submit", ["id": id])
    }

    func withdraw(id: String) async throws {
        _ = try await transport.mutation("articles:withdraw", ["id": id])
    }

    func remove(id: String) async throws {
        _ = try await transport.mutation("articles:remove", ["id": id])
    }

    func queue() async throws -> [Submission] {
        try JSONDecoder().decode([Submission].self, from: try await transport.query("articles:queue"))
    }

    func review(id: String, approve: Bool, note: String?) async throws {
        var args: [String: Any] = ["id": id, "approve": approve]
        if let note, !note.isEmpty { args["note"] = note }
        _ = try await transport.mutation("articles:review", args)
    }
}

/// Every article the app can show: what practitioners have had approved, then
/// the ones bundled with the app.
///
/// Shared so Home, a See all list and search all read the same shelf, and one
/// fetch serves them. If the server cannot be reached the bundled articles are
/// still there, so Home is never an empty page because of a network.
@MainActor
final class ArticleLibrary: ObservableObject {
    static let shared = ArticleLibrary()

    @Published private(set) var all: [Article] = Articles.bundled

    func refresh() async {
        guard let published = try? await ArticlesClient().published() else { return }
        let ids = Set(published.map(\.id))
        all = published + Articles.bundled.filter { !ids.contains($0.id) }
    }

    var categories: [String] {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }
    }

    func filed(under category: String) -> [Article] {
        all.filter { $0.category == category }
    }
}
