import Foundation

/// Where the app talks to, and nothing else.
///
/// One address: the database. There was a second, a web app of ours holding
/// the AI keys, the payment processors and a SQLite file on a Mac, and every
/// feature that used it was broken whenever that machine was asleep. All of it
/// is either on Convex now or gone, so a phone app needs no computer of ours.
enum AppConfig {

    /// The database, spoken to directly.
    ///
    /// The same address in development and production, which is the point of
    /// it. There is no host to stamp at build time, no Mac that has to be
    /// awake, and no insecure-HTTP exception, because there is no machine of
    /// yours in the path at all.
    static let convexURL = "https://wary-penguin-35.convex.cloud"

    /// Provider key this app reports as — see PROVIDERS in convex/health/metrics.ts
    static let provider = "apple_health"

    /// The privacy policy and the terms, served by the same deployment.
    ///
    /// `.site` rather than `.cloud`: the same deployment answers both, but
    /// pages live on one and the API on the other. Written out rather than
    /// derived from convexURL, so a typo here fails to compile rather than
    /// shipping a link that opens nothing.
    static let privacyURL = URL(string: "https://wary-penguin-35.convex.site/privacy")!
    static let termsURL = URL(string: "https://wary-penguin-35.convex.site/terms")!

    /// Resume token from the last anchored query, so each sync asks only for
    /// what changed. Opaque to us; the server round-trips it.
    private static let cursorKey = "personal_os_sync_cursor"

    static var syncCursor: String? {
        get { UserDefaults.standard.string(forKey: cursorKey) }
        set { UserDefaults.standard.set(newValue, forKey: cursorKey) }
    }
}
