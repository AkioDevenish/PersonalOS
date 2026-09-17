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
    ///
    /// Only three things still go through it: the two AI routes and the sync,
    /// which do real work rather than forwarding. Everything else now talks to
    /// Convex directly.
    static let productionBaseURL = "https://web-iota-eight-97.vercel.app"

    /// The database, spoken to directly.
    ///
    /// The same address in development and production, which is the point of
    /// it. There is no host to stamp at build time, no Mac that has to be
    /// awake, and no insecure-HTTP exception, because there is no machine of
    /// yours in the path at all.
    static let convexURL = "https://wary-penguin-35.convex.cloud"

    /// Where the app talks to, in every build.
    ///
    /// Debug builds used to point at whichever Mac compiled them: a build
    /// phase wrote that Mac's LAN address into the Info.plist, added an
    /// exception so the app could speak plain HTTP to it, and a field in
    /// Settings let the address be typed over. All of it is gone. Nothing
    /// about running this app should depend on a particular computer being
    /// awake on the same network, and an app that trusts insecure HTTP to an
    /// address somebody typed is not one to hand to anybody else.
    static let baseURL = productionBaseURL

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

/// Whether the web service is actually there.
///
/// Three things still need it — connecting a watch or ring, pulling from one,
/// and checking an App Store receipt — and all three were failing as a
/// timeout against an address nobody answered. Neither build could reach one:
/// the debug build points at whichever Mac compiled it, which is not usually
/// awake or even on the same network, and production answered 404 to every
/// path including its own static pages.
///
/// Asked rather than assumed, and asked once. A constant saying "there is no
/// server" would be right today and quietly wrong the morning after a deploy,
/// which is the same failure in the other direction. The check is lazy, so an
/// app that never touches those three things never makes the request.
actor ServerReachability {
    static let shared = ServerReachability()

    private var answer: Bool?

    func isUp() async -> Bool {
        if let answer { return answer }
        let result = await probe()
        answer = result
        return result
    }

    /// Forgets the answer, so the next ask finds out again. For the moment
    /// after somebody has been told the service is down and has gone and
    /// started it.
    func recheck() { answer = nil }

    private func probe() async -> Bool {
        guard let url = URL(string: AppConfig.baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        // Short: this runs while somebody is waiting to find out whether a
        // button will work, and a slow no is worse than a fast one.
        request.timeoutInterval = 4
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        // Any answer at all means something is listening and routing. A 404 on
        // the root is what a deployment that no longer holds this app returns,
        // and that is not a server for our purposes.
        return http.statusCode != 404
    }
}
