import Foundation

/// Talks to the model-settings routes.
///
/// The one rule this client exists to keep: an API key travels up and is never
/// asked for again. There is no endpoint that returns one, nothing here stores
/// one, and the only thing the app ever displays is the last four characters
/// the server sends back. If the user wants to change a key they type the whole
/// thing again — which is correct, because neither the app nor the server
/// should be able to show someone a credential they've already handed over.
struct AIClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) { self.auth = auth }

    // MARK: Shapes

    struct Provider: Decodable, Identifiable, Hashable {
        let id: String
        let label: String
        let aka: String?
        let needsKey: Bool
        let keyPrefix: String?
        let models: [String]
        let consoleURL: String?

        /// "Anthropic (Claude)" reads better than either half alone.
        var title: String {
            guard let aka, !aka.isEmpty else { return label }
            return "\(label) · \(aka)"
        }
    }

    struct StoredKey: Decodable, Hashable {
        let provider: String
        let last4: String
        let updated_at: Double
    }

    struct Selection: Decodable, Hashable {
        let provider: String
        let model: String
    }

    struct Settings: Decodable {
        let providers: [Provider]
        let keys: [StoredKey]
        let selection: Selection?
    }

    private struct MutationResponse: Decodable {
        let keys: [StoredKey]?
        let selection: Selection?
        let verifiedWith: String?
        let error: String?
    }

    // MARK: Calls

    func settings() async throws -> Settings {
        let data = try await send(request("/api/ai/settings", method: "GET", body: nil))
        return try JSONDecoder().decode(Settings.self, from: data)
    }

    /// Saves a key. The server proves it against the provider before storing,
    /// so a slow return here means it is genuinely being checked.
    @discardableResult
    func saveKey(provider: String, apiKey: String) async throws -> String? {
        var r = try await request("/api/ai/keys", method: "POST",
                                  body: ["provider": provider, "apiKey": apiKey])
        // Verification is a live round trip to someone else's API.
        r.timeoutInterval = 60
        let data = try await send(r)
        return (try? JSONDecoder().decode(MutationResponse.self, from: data))?.verifiedWith
    }

    func deleteKey(provider: String) async throws {
        let path = "/api/ai/keys?provider=\(provider.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? provider)"
        _ = try await send(request(path, method: "DELETE", body: nil))
    }

    func select(provider: String, model: String) async throws {
        _ = try await send(request("/api/ai/settings", method: "PUT",
                                   body: ["provider": provider, "model": model]))
    }

    // MARK: Transport

    private func request(_ path: String, method: String, body: [String: Any]?) async throws -> URLRequest {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw AIError.badURL }
        guard let token = await auth.currentToken() else { throw AIError.notSignedIn }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 30
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    private func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            // The routes explain themselves — a revoked key, an unreachable
            // model — so prefer the server's wording over a status code.
            let detail = (try? JSONDecoder().decode(MutationResponse.self, from: data))?.error
            throw AIError.server(detail ?? "Request failed (\(http.statusCode))")
        }
        return data
    }
}

enum AIError: LocalizedError {
    case badURL, badResponse, notSignedIn
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .badResponse: return "Unexpected server response"
        case .notSignedIn: return "Sign in to manage models"
        case .server(let m): return m
        }
    }
}
