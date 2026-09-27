import Foundation
import Combine
import StoreKit

/// Articles on the server: what is published, what an author has written, and what is waiting for a
/// reviewer.
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
        let live_until: Double?
        let updated_at: Double

        var statusText: String {
            switch status {
            case "submitted": return "Waiting for review"
            case "changes_requested": return "Changes requested"
            case "approved": return "Verified · pay to publish"
            case "published": return "On Home"
            case "expired": return "Expired"
            case "withdrawn": return "Withdrawn"
            default: return "Draft"
            }
        }

        /// Whether a purchase can be made for it: verified, live, or run out.
        var canPay: Bool { ["approved", "published", "expired"].contains(status) }

        var liveUntil: Date? { live_until.map { Date(timeIntervalSince1970: $0 / 1000) } }
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
        let data = try await transport.query(
            "articles:published", ["now": Date().timeIntervalSince1970 * 1000]
        )
        return try JSONDecoder().decode([Article].self, from: data)
    }

    /// The back catalogue.
    func archive() async throws -> [Article] {
        let data = try await transport.query(
            "articles:archive", ["now": Date().timeIntervalSince1970 * 1000]
        )
        return try JSONDecoder().decode([Article].self, from: data)
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

    /// The token a purchase must carry to count for this article.
    func startPayment(id: String) async throws -> UUID {
        struct Started: Decodable { let token: String }
        let started = try JSONDecoder().decode(
            Started.self, from: try await transport.mutation("articles:startPayment", ["id": id])
        )
        guard let uuid = UUID(uuidString: started.token) else { throw TransportError.badResponse }
        return uuid
    }

    /// Hands Apple's signed transaction to the server, which checks the signature and applies the
    /// time on Home.
    func confirmPlacement(signedTransaction: String) async throws {
        _ = try await transport.action(
            "articlePayments:confirmPlacement", ["signedTransaction": signedTransaction]
        )
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

/// Every article the app can show: what practitioners have had approved, then the ones bundled with
/// the app.
@MainActor
final class ArticleLibrary: ObservableObject {
    static let shared = ArticleLibrary()

    @Published private(set) var all: [Article] = Articles.bundled
    /// Articles whose time on Home has run out.
    @Published private(set) var archive: [Article] = []

    func refresh() async {
        let client = ArticlesClient()
        if let published = try? await client.published() {
            let ids = Set(published.map(\.id))
            all = published + Articles.bundled.filter { !ids.contains($0.id) }
        }
        archive = (try? await client.archive()) ?? []
    }

    var categories: [String] {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }
    }

    func filed(under category: String) -> [Article] {
        all.filter { $0.category == category }
    }
}

/// Buying thirty days on Home for one article.
@MainActor
enum ArticlePlacement {
    static let productID = "os.personal.article.30days"

    enum Outcome { case placed, cancelled, pending }

    static func product() async -> Product? {
        try? await Product.products(for: [productID]).first
    }

    static func buy(articleID: String) async throws -> Outcome {
        guard let product = await product() else {
            throw PlacementError.unavailable
        }
        let token = try await ArticlesClient().startPayment(id: articleID)
        switch try await product.purchase(options: [.appAccountToken(token)]) {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw PlacementError.unverified }
            try await ArticlesClient().confirmPlacement(signedTransaction: verification.jwsRepresentation)
            await transaction.finish()
            await ArticleLibrary.shared.refresh()
            return .placed
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// For a transaction StoreKit redelivered.
    static func confirm(_ verification: VerificationResult<Transaction>) async -> Bool {
        do {
            try await ArticlesClient().confirmPlacement(signedTransaction: verification.jwsRepresentation)
            await ArticleLibrary.shared.refresh()
            return true
        } catch {
            return false
        }
    }

    enum PlacementError: LocalizedError {
        case unavailable, unverified
        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Publishing isn't on sale yet. It needs the product set up in App Store Connect."
            case .unverified:
                return "The App Store couldn't verify that purchase."
            }
        }
    }
}
