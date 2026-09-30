import Foundation

/// Where the app talks to, and nothing else.
enum AppConfig {

    /// The Convex deployment: dev for Debug builds, production for TestFlight and the App Store.
    #if DEBUG
    private static let deployment = "wary-penguin-35"
    #else
    private static let deployment = "astute-ant-253"
    #endif

    /// The database, spoken to directly.
    static let convexURL = "https://\(deployment).convex.cloud"

    /// Provider key this app reports as — see PROVIDERS in convex/health/metrics.ts
    static let provider = "apple_health"

    /// The privacy policy and the terms, served by the same deployment.
    static let privacyURL = URL(string: "https://\(deployment).convex.site/privacy")!
    static let termsURL = URL(string: "https://\(deployment).convex.site/terms")!

    /// Whether this build carries the Sign in with Apple entitlement, which Apple's own sheet needs.
    /// Keep it in step with `com.apple.developer.applesignin` in Forklore.entitlements.
    static let appleSignInSheet = false

    /// Resume token from the last anchored query, so each sync asks only for what changed.
    private static let cursorKey = "personal_os_sync_cursor"

    static var syncCursor: String? {
        get { UserDefaults.standard.string(forKey: cursorKey) }
        set { UserDefaults.standard.set(newValue, forKey: cursorKey) }
    }
}
