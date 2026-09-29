import Foundation

/// Supplies the bearer token that identifies the signed-in user.
protocol AuthProvider {
    /// Nil when nobody is signed in.
    func currentToken() async -> String?
}

/// The app's own sessions, from convex/auth.ts.
struct SessionAuthProvider: AuthProvider {
    func currentToken() async -> String? {
        await Session.shared.validToken()
    }
}

enum Auth {
    static var provider: AuthProvider { SessionAuthProvider() }
}
