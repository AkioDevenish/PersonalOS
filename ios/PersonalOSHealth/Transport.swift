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
