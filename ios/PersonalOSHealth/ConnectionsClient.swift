import Foundation
import AuthenticationServices

/// Linking and syncing the wearables.
///
/// The connect step is a real OAuth round trip through the provider's own
/// login page, run in `ASWebAuthenticationSession` — the system browser sheet
/// rather than an in-app web view. That matters: the user sees the real
/// address bar and the padlock, the app never touches their Oura or Fitbit
/// password, and the session cookie jar is not ours to read.
/// Not observable: the view owns the connection list as its own state, and the
/// only reason this is a class at all is that ASWebAuthenticationSession needs
/// a presentation-anchor delegate to hold on to.
@MainActor
final class ConnectionsClient: NSObject {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) {
        self.auth = auth
        super.init()
    }

    struct Connection: Decodable, Identifiable, Hashable {
        let key: String
        let label: String
        /// cloud | device. A device provider is one whose data arrives from an
        /// app on a phone rather than over OAuth — Apple Health here, Health
        /// Connect and Samsung Health on Android. The registry is shared with
        /// the web, so this list arrives holding all three.
        let kind: String?
        /// device providers only: which phone has to be doing the pushing.
        let platform: String?
        let status: String            // connected | pending | disconnected
        let last_sync_at: Double?
        let last_error: String?
        /// Whether this deployment holds the client credentials to offer a link.
        let configured: Bool
        /// Whether a pull adapter exists for it.
        let syncable: Bool

        var id: String { key }
        var isConnected: Bool { status == "connected" }
    }

    private struct ListResponse: Decodable { let connections: [Connection] }
    private struct LinkResponse: Decodable { let url: String?; let error: String? }
    private struct SyncResponse: Decodable {
        let pulled: Int?
        let written: Int?
        let note: String?
        let error: String?
    }

    /// The providers this phone can actually offer to link.
    ///
    /// The route returns every connectable provider the product knows about,
    /// because the same registry serves the web. Two kinds of row in that list
    /// are wrong on an iPhone: Apple Health, which the app draws itself from
    /// what HealthKit reports rather than from a server row — it appeared
    /// twice otherwise — and the Android device providers, which no amount of
    /// tapping here can connect. Filtered at the transport so every caller
    /// sees the same honest list.
    func list() async throws -> [Connection] {
        let data = try await send(try await request("/api/health/connections", method: "GET"))
        let all = try JSONDecoder().decode(ListResponse.self, from: data).connections
        return all.filter { $0.kind != "device" }
    }

    /// Opens the provider's login, returns once the callback lands.
    func connect(_ provider: String) async throws {
        let data = try await send(
            try await request("/api/health/oauth/\(provider)/link-url", method: "GET")
        )
        guard let link = try? JSONDecoder().decode(LinkResponse.self, from: data),
              let urlString = link.url,
              let url = URL(string: urlString) else {
            throw ConnectionError.server("Couldn't start the connection.")
        }

        // The callback redirects back to the server, which renders a small
        // page; the sheet closes when it reaches that origin.
        _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: nil
            ) { callbackURL, error in
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    cont.resume(throwing: cancelled ? ConnectionError.cancelled
                                                    : ConnectionError.server(error.localizedDescription))
                    return
                }
                cont.resume(returning: callbackURL ?? url)
            }
            session.presentationContextProvider = self
            // Providers keep their own login cookies; sharing the system
            // session means someone already signed in to Oura isn't asked
            // to type their password again.
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    /// Pulls a window of days from a connected provider into the ledger.
    @discardableResult
    func sync(_ provider: String, days: Int = 7) async throws -> String {
        var r = try await request("/api/health/sync/\(provider)", method: "POST")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["days": days])
        r.timeoutInterval = 90   // three upstream APIs, sequential windows

        let data = try await send(r)
        let res = try? JSONDecoder().decode(SyncResponse.self, from: data)
        if let note = res?.note { return note }
        let written = res?.written ?? res?.pulled ?? 0
        return written == 0 ? "Nothing new." : "Added \(written) readings."
    }

    // MARK: Transport

    private func request(_ path: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw ConnectionError.badURL }
        guard let token = await auth.currentToken() else { throw ConnectionError.notSignedIn }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 30
        return r
    }

    private func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw ConnectionError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            // The routes explain themselves — an unconfigured provider, an
            // expired grant — so prefer their wording to a status code.
            let detail = (try? JSONDecoder().decode(SyncResponse.self, from: data))?.error
            throw ConnectionError.server(detail ?? "Request failed (\(http.statusCode))")
        }
        return data
    }
}

extension ConnectionsClient: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}

enum ConnectionError: LocalizedError {
    case badURL, badResponse, notSignedIn, cancelled
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .badResponse: return "Unexpected server response"
        case .notSignedIn: return "Sign in to manage connections"
        case .cancelled: return "Connection cancelled."
        case .server(let m): return m
        }
    }
}
