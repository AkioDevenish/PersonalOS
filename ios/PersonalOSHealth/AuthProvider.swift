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

enum Auth {
    /// Clerk is the identity, in every build.
    ///
    /// A debug build used to accept a token pasted into Settings instead of
    /// signing in. That is a sign-in bypass shipped in the same binary as the
    /// real thing, kept apart from it by one compiler flag, and it existed to
    /// test against a server on a Mac. Both reasons are gone.
    static var provider: AuthProvider { ClerkAuthProvider() }

    /// Publishable key — safe in a client: it names the instance, it grants
    /// nothing. Decoded, it is hopeful-collie-6.clerk.accounts.dev.
    static let publishableKey = "pk_test_aG9wZWZ1bC1jb2xsaWUtNi5jbGVyay5hY2NvdW50cy5kZXYk"
}
