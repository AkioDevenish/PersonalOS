import Foundation

/// Reads the three non-health pillars.
///
/// Business, Creative and Data each had a Convex module written for the old
/// web dashboard and left stranded when the website came down. Nothing was
/// lost — the tables and queries were still deployed — so these views are
/// putting an existing spine back in reach rather than inventing new storage.
///
/// One request per pillar, because a phone drawing one screen should not make
/// four round trips to do it.
struct PillarClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) { self.auth = auth }

    // MARK: Business

    struct Contact: Decodable, Identifiable, Hashable {
        let _id: String
        let name: String
        let email: String?
        let company: String?
        let status: String
        let notes: String?
        var id: String { _id }
    }

    struct Pipeline: Decodable {
        /// Counts keyed by status — lead, prospect, proposal, client.
        let summary: [String: Int]
    }

    struct BusinessPayload: Decodable {
        let contacts: [Contact]
        let pipeline: Pipeline?
    }

    func business() async throws -> BusinessPayload {
        try JSONDecoder().decode(BusinessPayload.self, from: await get("business"))
    }

    // MARK: Creative

    struct Post: Decodable, Identifiable, Hashable {
        let _id: String
        let content: String
        let platform: String
        let topic: String?
        let published: Bool
        let created_at: Double
        var id: String { _id }
    }

    struct CreativeStats: Decodable {
        let total: Int
        let published: Int
        let this_week: Int
    }

    struct CreativePayload: Decodable {
        let posts: [Post]
        let stats: CreativeStats?
    }

    func creative() async throws -> CreativePayload {
        try JSONDecoder().decode(CreativePayload.self, from: await get("creative"))
    }

    // MARK: Data

    struct Project: Decodable, Identifiable, Hashable {
        let _id: String
        let name: String
        let description: String?
        let status: String
        let started_date: String?
        let deployed_url: String?
        let github_url: String?
        let tags: String?
        var id: String { _id }
    }

    struct DataPayload: Decodable {
        let projects: [Project]
    }

    func data() async throws -> DataPayload {
        try JSONDecoder().decode(DataPayload.self, from: await get("data"))
    }

    // MARK: Transport

    private struct ErrorBody: Decodable { let error: String? }

    private func get(_ pillar: String) async throws -> Data {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/pillars?pillar=\(pillar)") else {
            throw PillarError.badURL
        }
        guard let token = await auth.currentToken() else { throw PillarError.notSignedIn }
        var r = URLRequest(url: url)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 30

        let (body, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw PillarError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.error
            throw PillarError.server(detail ?? "Couldn't load (\(http.statusCode))")
        }
        return body
    }
}

enum PillarError: LocalizedError {
    case badURL, badResponse, notSignedIn
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .badResponse: return "Unexpected server response"
        case .notSignedIn: return "Sign in to see this"
        case .server(let m): return m
        }
    }
}
