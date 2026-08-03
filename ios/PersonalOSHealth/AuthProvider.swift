import Foundation
import ClerkKit

/// Supplies the bearer token that identifies the signed-in user.
///
/// Kept behind a protocol so the networking layer never knows which auth SDK
/// is in use — and so a debug build can still sync with a pasted token when
/// that's quicker than signing in.
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

/// Real implementation, backed by the Clerk iOS SDK.
///
/// The template name must be "convex": it matches the JWT template in the
/// Clerk dashboard, `applicationID: "convex"` in convex/auth.config.ts, and
/// what the API route verifies. Any other template and the server rejects it.
struct ClerkAuthProvider: AuthProvider {
    static let jwtTemplate = "convex"

    var isSignedIn: Bool {
        MainActor.assumeIsolated { Clerk.shared.user != nil }
    }

    func currentToken() async -> String? {
        guard let session = await MainActor.run(body: { Clerk.shared.session }) else { return nil }
        return try? await session.getToken(.init(template: Self.jwtTemplate))
    }
}

#if DEBUG
/// Escape hatch for development: paste a session token instead of signing in.
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
    /// Clerk is the identity. In debug builds a pasted token wins if present,
    /// so a device can sync without a full sign-in when testing.
    static var provider: AuthProvider {
        #if DEBUG
        if !DebugTokenAuthProvider.token.isEmpty { return DebugTokenAuthProvider() }
        #endif
        return ClerkAuthProvider()
    }

    /// Publishable key — safe in a client: it names the instance, it grants
    /// nothing. Decoded, it is hopeful-collie-6.clerk.accounts.dev.
    static let publishableKey = "pk_test_aG9wZWZ1bC1jb2xsaWUtNi5jbGVyay5hY2NvdW50cy5kZXYk"
}
