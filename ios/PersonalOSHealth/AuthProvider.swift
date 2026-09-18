import Foundation

/// Supplies the bearer token that identifies the signed-in user.
///
/// Kept behind a protocol so the networking layer never knows how signing in
/// works, only that it can ask for a token.
protocol AuthProvider {
    /// Nil when nobody is signed in.
    func currentToken() async -> String?
}

/// The app's own sessions, from convex/auth.ts.
///
/// This used to be Clerk. Accounts now live in the app's own database, and
/// the token is one that deployment signed itself.
struct SessionAuthProvider: AuthProvider {
    func currentToken() async -> String? {
        await Session.shared.validToken()
    }
}

enum Auth {
    static var provider: AuthProvider { SessionAuthProvider() }
}
