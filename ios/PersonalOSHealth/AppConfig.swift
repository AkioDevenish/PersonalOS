import Foundation

/// Where the app talks to, and nothing else.
enum AppConfig {

    /// The database, spoken to directly.
    static let convexURL = "https://wary-penguin-35.convex.cloud"

    /// Provider key this app reports as — see PROVIDERS in convex/health/metrics.ts
    static let provider = "apple_health"

    /// The privacy policy and the terms, served by the same deployment.
    static let privacyURL = URL(string: "https://wary-penguin-35.convex.site/privacy")!
    static let termsURL = URL(string: "https://wary-penguin-35.convex.site/terms")!

    /// Resume token from the last anchored query, so each sync asks only for what changed.
    private static let cursorKey = "personal_os_sync_cursor"

    static var syncCursor: String? {
        get { UserDefaults.standard.string(forKey: cursorKey) }
        set { UserDefaults.standard.set(newValue, forKey: cursorKey) }
    }
}
