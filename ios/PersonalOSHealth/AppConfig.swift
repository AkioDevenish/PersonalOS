import Foundation

/// Where the app talks to, and nothing else.
///
/// This used to also hold an ingest token, a user id and a workspace id, all
/// editable in the UI. They're gone: identity now comes from the signed-in
/// Clerk session, so there is nothing for anyone to type in — and no way for a
/// device to claim to be a different account.
///
/// The server URL is a constant in release builds. It stays adjustable in
/// DEBUG only, because developing against a Mac over Wi-Fi needs an IP that
/// changes.
enum AppConfig {

    /// Production hub. Change this once, here, when the domain changes.
    static let productionBaseURL = "https://web-iota-eight-97.vercel.app"

    #if DEBUG
    private static let debugBaseURLKey = "personal_os_debug_base_url"

    /// Defaults to the Mac's LAN address; 127.0.0.1 will not resolve from a phone.
    static var baseURL: String {
        get {
            UserDefaults.standard.string(forKey: debugBaseURLKey) ?? "http://192.168.100.206:3000"
        }
        set {
            UserDefaults.standard.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: debugBaseURLKey
            )
        }
    }
    #else
    static let baseURL = productionBaseURL
    #endif

    /// Ingest endpoint. Identity travels in the Authorization header.
    static let ingestPath = "api/health/ingest"

    /// Provider key this app reports as — see PROVIDERS in convex/health/metrics.ts
    static let provider = "apple_health"

    /// Resume token from the last anchored query, so each sync asks only for
    /// what changed. Opaque to us; the server round-trips it.
    private static let cursorKey = "personal_os_sync_cursor"

    static var syncCursor: String? {
        get { UserDefaults.standard.string(forKey: cursorKey) }
        set { UserDefaults.standard.set(newValue, forKey: cursorKey) }
    }
}
