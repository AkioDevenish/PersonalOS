import Foundation

/// One way of talking to the server.
///
/// Six clients each carried a private copy of this: the same bearer header, the
/// same JSON body, the same status check, the same mapping from a code to a
/// sentence. They differed only in timeout, and they had already begun to
/// drift, with the message for an expired session written out twice in two
/// files and no reason to expect the third one to match.
///
/// The clients keep their own shapes and their own routes. What they share is
/// the part that has nothing to do with what they are asking for.
struct Transport {
    private let auth: AuthProvider
    private let timeout: TimeInterval

    /// Local model inference is not fast, which is the only reason any caller
    /// needs a different number here.
    init(auth: AuthProvider = Auth.provider, timeout: TimeInterval = 30) {
        self.auth = auth
        self.timeout = timeout
    }

    func get(_ path: String) async throws -> Data {
        try await send(request(path, method: "GET", body: nil))
    }

    func post(_ path: String, body: [String: Any]) async throws -> Data {
        try await send(request(path, method: "POST", body: body))
    }

    func send(_ path: String, method: String, body: [String: Any]? = nil) async throws -> Data {
        try await send(request(path, method: method, body: body))
    }

    // MARK: Convex, directly

    /// Calls a Convex function without anything in between.
    ///
    /// Convex takes the same bearer token the routes did, so the phone can ask
    /// the database itself rather than asking a server to ask it. That removes
    /// the whole middle: no host to stamp into the build, no Mac that has to
    /// be awake, no plaintext exception, and one place to deploy instead of
    /// two.
    ///
    /// `path` is Convex's own naming — "finance:ledger", or
    /// "health/consult:directory" for a function in a folder.
    func query(_ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call("query", path, args)
    }

    func mutation(_ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call("mutation", path, args)
    }

    /// An action, for the functions that reach outside Convex — minting a
    /// video room, taking a payment. They live there rather than here because
    /// they hold keys, and a key in an app is a key anybody can read out of it.
    func action(_ path: String, _ args: [String: Any] = [:]) async throws -> Data {
        try await call("action", path, args)
    }

    private func call(_ kind: String, _ path: String, _ args: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(AppConfig.convexURL)/api/\(kind)") else {
            throw TransportError.badURL
        }
        guard let token = await auth.currentToken() else { throw TransportError.notSignedIn }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

        // Convex answers 200 even when the function threw, with the failure in
        // the envelope. Treating that as success is how an error becomes a
        // blank screen instead of a sentence.
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

    private func request(_ path: String, method: String, body: [String: Any]?) async throws -> URLRequest {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw TransportError.badURL }
        guard let token = await auth.currentToken() else { throw TransportError.notSignedIn }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = timeout
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    private func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw TransportError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            throw TransportError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}

/// What went wrong, in words a person can act on.
///
/// Written once. The 500 explains the Mac because that is where the local model
/// lives, which is the single most common cause of one in this app.
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
            if code == 500 { return "The server didn't answer. Is the Mac awake with Ollama running?" }
            return "Request failed (\(code))"
        }
    }
}

extension Error {
    /// Whether this is the request being called off rather than failing.
    ///
    /// SwiftUI cancels a `.task` every time it rebuilds the view that owns it,
    /// which happens on the way in from the drawer and on any parent redraw.
    /// The URL loading system reports that as an error, and its description is
    /// the single word "cancelled" — which reads, to somebody looking at a
    /// screen, as though the server refused them. Nothing was refused and
    /// there is nothing to act on, so it is never shown.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let url = self as? URLError { return url.code == .cancelled }
        return false
    }
}
