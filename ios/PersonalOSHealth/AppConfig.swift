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

    #if DEBUG
    private static let debugBaseURLKey = "personal_os_debug_base_url"

    /// Build-time LAN address of the Mac that compiled this build.
    ///
    /// Injected by the build phase in Scripts/dev-host.sh rather than typed in
    /// — a hardcoded IP goes stale the moment DHCP moves the Mac, and the
    /// symptom is a sync that hangs against an address nobody owns.
    private static var compiledHost: String? {
        Bundle.main.object(forInfoDictionaryKey: "DevServerHost") as? String
    }

    /// 127.0.0.1 is the phone itself, so a LAN address is required on device.
    /// Which build's host an override was made against.
    private static let overrideStampKey = "personal_os_debug_base_url_stamp"

    /// A manual override is honoured only while the build it was typed into
    /// still points at the same machine. Otherwise a value saved before the
    /// Mac's DHCP lease moved would silently outrank the freshly stamped host
    /// — and, being an unexpected address, would also fall outside the ATS
    /// exception this build carries.
    static var baseURL: String {
        get {
            let stamped = compiledHost ?? ""
            if let manual = UserDefaults.standard.string(forKey: debugBaseURLKey),
               !manual.isEmpty,
               UserDefaults.standard.string(forKey: overrideStampKey) == stamped {
                return manual
            }
            return stamped.isEmpty ? "http://localhost:3000" : "http://\(stamped):3000"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let stamped = compiledHost ?? ""
            // Saving the build default is not an override; keep it clean so a
            // later rebuild is free to move the host.
            if trimmed.isEmpty || trimmed == "http://\(stamped):3000" {
                UserDefaults.standard.removeObject(forKey: debugBaseURLKey)
                UserDefaults.standard.removeObject(forKey: overrideStampKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: debugBaseURLKey)
                UserDefaults.standard.set(stamped, forKey: overrideStampKey)
            }
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
