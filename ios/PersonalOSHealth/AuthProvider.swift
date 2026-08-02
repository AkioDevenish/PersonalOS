import Foundation

/// Supplies the bearer token that identifies the signed-in user.
///
/// Kept behind a protocol so the networking layer never knows which auth SDK
/// is in use, and so the app still builds before the Clerk package is added in
/// Xcode. Add it via File → Add Package Dependencies:
///
///     https://github.com/clerk/clerk-ios
///
/// Once it resolves, `canImport(Clerk)` becomes true and ClerkAuthProvider
/// compiles in with no other change.
protocol AuthProvider {
    /// Nil when nobody is signed in — the caller should not attempt to upload.
    func currentToken() async -> String?
    var isSignedIn: Bool { get }
}

enum AuthError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to sync your health data"
        }
    }
}

#if canImport(Clerk)
import Clerk

/// Real implementation.
///
/// The template name must be "convex" — it matches the JWT template in the
/// Clerk dashboard, `getToken({ template: "convex" })` in the ingest route,
/// and `applicationID: "convex"` in convex/auth.config.ts.
struct ClerkAuthProvider: AuthProvider {
    static let jwtTemplate = "convex"

    var isSignedIn: Bool {
        Clerk.shared.user != nil
    }

    func currentToken() async -> String? {
        guard let session = Clerk.shared.session else { return nil }
        // NOTE: verify this call against the clerk-ios version you install —
        // the getToken signature has changed across releases. The template
        // name is the part that must not change.
        return try? await session.getToken(
            GetTokenOptions(template: Self.jwtTemplate)
        )?.jwt
    }
}
#endif

#if DEBUG
/// Local development without the Clerk package: paste a session token from the
/// browser (Application → Cookies, or a getToken() call in the console).
/// Never compiled into a release build.
struct DebugTokenAuthProvider: AuthProvider {
    private static let key = "personal_os_debug_token"

    static var token: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key) }
    }

    var isSignedIn: Bool { !Self.token.isEmpty }
    func currentToken() async -> String? { Self.token.isEmpty ? nil : Self.token }
}
#endif

enum Auth {
    /// The provider the app actually uses. Prefers Clerk when the package is
    /// present, falls back to the debug token so the app runs before it is.
    static var provider: AuthProvider = {
        #if canImport(Clerk)
        return ClerkAuthProvider()
        #elseif DEBUG
        return DebugTokenAuthProvider()
        #else
        // A release build without the Clerk package cannot authenticate anyone.
        fatalError("Add the clerk-ios package before shipping a release build")
        #endif
    }()
}
