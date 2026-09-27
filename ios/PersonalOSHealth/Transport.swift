import Foundation

/// One way of talking to Convex.
struct Transport {
    private let auth: AuthProvider
    private let timeout: TimeInterval

    /// Local model inference is not fast, which is the only reason any caller needs a different
    /// number here.
    init(auth: AuthProvider = Auth.provider, timeout: TimeInterval = 30) {
        self.auth = auth
        self.timeout = timeout
    }

    // MARK: Convex, directly

    /// Calls a Convex function without anything in between.
    func query(_ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call("query", path, args)
    }

    func mutation(_ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call("mutation", path, args)
    }

    /// An action, for the functions that reach outside Convex — minting a video room, taking a
    /// payment.
    func action(_ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call("action", path, args)
    }

    /// A call made before anybody has signed in: signing up, signing in, and asking which providers
    /// exist.
    func anonymous(_ kind: String, _ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call(kind, path, args, token: nil)
    }

    private func call(_ kind: String, _ path: String, _ args: [String: Any]) async throws -> Data {
        guard let token = await auth.currentToken() else { throw TransportError.notSignedIn }
        return try await call(kind, path, args, token: token)
    }

    private func call(_ kind: String, _ path: String, _ args: [String: Any], token: String?) async throws -> Data {
        guard let url = URL(string: "\(AppConfig.convexURL)/api/\(kind)") else {
            throw TransportError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["path": path, "args": args, "format": "json"]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TransportError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            throw TransportError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        // Convex answers 200 even when the function threw, with the failure in the envelope.
        struct Envelope: Decodable {
            let status: String
            let errorMessage: String?
        }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
           envelope.status != "success" {
            throw TransportError.server(envelope.errorMessage ?? "The database refused that")
        }

        // The caller wants the value, not the wrapper around it.
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TransportError.badResponse
        }
        let value = object["value"] ?? NSNull()
        return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    }

}

/// What went wrong, in words a person can act on.
enum TransportError: LocalizedError {
    case badURL, badResponse, notSignedIn
    case http(Int, String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .badResponse: return "Unexpected server response"
        case .notSignedIn: return "Sign in to continue"
        case .server(let m): return m
        case .http(let code, _):
            if code == 401 { return "Your session expired. Sign in again" }
            return "Request failed (\(code))"
        }
    }
}

extension Error {
    /// Whether this is the request being called off rather than failing.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let url = self as? URLError { return url.code == .cancelled }
        return false
    }
}
