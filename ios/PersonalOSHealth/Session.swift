import Foundation
import Combine
import Security
import AuthenticationServices
import UIKit

/// Who is signed in, run by this app rather than by a service.
///
/// Accounts live in the app's own Convex database (convex/auth.ts). Signing in
/// hands back two tokens: a short-lived one sent with every request, and a
/// refresh token that buys the next. Both are kept in the Keychain, which is
/// encrypted, survives a relaunch, and is not in the phone's plain backups.
///
/// The session token is renewed shortly before it expires rather than after a
/// request is refused, so nothing somebody is doing ever fails because an hour
/// passed.
@MainActor
final class Session: NSObject, ObservableObject {
    static let shared = Session()

    enum State { case restoring, signedOut, signedIn }

    @Published private(set) var state: State = .restoring
    @Published private(set) var account: Account?

    struct Account: Decodable, Equatable {
        let id: String
        let name: String?
        let email: String?
        let image: String?

        var displayName: String {
            if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
            return email ?? "Your account"
        }
    }

    struct Providers: Decodable {
        let password: Bool
        let google: Bool
        let facebook: Bool
        let apple: Bool
    }

    enum Provider: String { case google, facebook, apple }

    private var token: String? { Keychain.read("session_token") }
    private var refreshToken: String? { Keychain.read("refresh_token") }
    /// One refresh at a time: several requests arriving together should wait
    /// on the same renewal, not each spend the refresh token.
    private var refreshing: Task<String?, Never>?

    private let transport = Transport()

    // MARK: Starting up

    /// On launch: signed in if a refresh token is on the device and still
    /// works, signed out otherwise. There is nothing to show until this is
    /// known, so it is fast and it is the first thing that runs.
    func restore() async {
        guard refreshToken != nil else { state = .signedOut; return }
        if await validToken() != nil {
            state = .signedIn
            await loadAccount()
        } else {
            state = .signedOut
        }
    }

    // MARK: Email and password

    func signUp(email: String, password: String, name: String) async throws {
        try await passwordFlow(["email": email, "password": password, "name": name, "flow": "signUp"])
    }

    func signIn(email: String, password: String) async throws {
        try await passwordFlow(["email": email, "password": password, "flow": "signIn"])
    }

    private func passwordFlow(_ params: [String: Any]) async throws {
        let data = try await transport.anonymous("action", "auth:signIn", [
            "provider": "password", "params": params,
        ])
        try await adopt(data)
    }

    // MARK: Google, Facebook, Apple

    /// Opens the provider in a secure browser sheet, which closes the moment
    /// it is sent back to the app with a one-time code; that code, with the
    /// verifier from the first step, is exchanged for tokens.
    func signIn(with provider: Provider) async throws {
        struct Started: Decodable { let redirect: String; let verifier: String }
        let data = try await transport.anonymous("action", "auth:signIn", [
            "provider": provider.rawValue,
            "params": ["redirectTo": "personalos://auth"],
        ])
        let started = try JSONDecoder().decode(Started.self, from: data)
        guard let url = URL(string: started.redirect) else { throw SessionError.badResponse }

        let callback: URL = try await withCheckedThrowingContinuation { done in
            let sheet = ASWebAuthenticationSession(url: url, callbackURLScheme: "personalos") { url, error in
                if let url { done.resume(returning: url) }
                else { done.resume(throwing: error ?? SessionError.cancelled) }
            }
            sheet.presentationContextProvider = self
            // Remembers somebody already signed in to Google in the browser,
            // so they are not asked for their password again.
            sheet.prefersEphemeralWebBrowserSession = false
            sheet.start()
        }

        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw SessionError.cancelled
        }
        let exchanged = try await transport.anonymous("action", "auth:signIn", [
            "provider": provider.rawValue,
            "params": ["code": code],
            "verifier": started.verifier,
        ])
        try await adopt(exchanged)
    }

    func providers() async -> Providers {
        let none = Providers(password: true, google: false, facebook: false, apple: false)
        guard let data = try? await transport.anonymous("query", "users:providers") else { return none }
        return (try? JSONDecoder().decode(Providers.self, from: data)) ?? none
    }

    // MARK: Signing out

    func signOut() async {
        // Ends the session on the server too, so the refresh token on this
        // phone stops being worth anything even if it were copied.
        _ = try? await transport.action("auth:signOut")
        Keychain.delete("session_token")
        Keychain.delete("refresh_token")
        account = nil
        state = .signedOut
    }

    // MARK: The account

    func loadAccount() async {
        guard let data = try? await transport.query("users:me") else { return }
        account = try? JSONDecoder().decode(Account.self, from: data)
    }

    func rename(_ name: String) async throws {
        _ = try await transport.mutation("users:setName", ["name": name])
        await loadAccount()
    }

    // MARK: Tokens

    /// A token good for at least another minute, renewing it if needed.
    func validToken() async -> String? {
        if let token, let expiry = Self.expiry(of: token), expiry.timeIntervalSinceNow > 60 {
            return token
        }
        if let refreshing { return await refreshing.value }
        let task = Task<String?, Never> { await self.refresh() }
        refreshing = task
        let fresh = await task.value
        refreshing = nil
        return fresh
    }

    private func refresh() async -> String? {
        guard let refreshToken else { return nil }
        guard let data = try? await transport.anonymous("action", "auth:signIn", ["refreshToken": refreshToken]),
              (try? await adopt(data)) != nil
        else {
            // A refresh token that no longer works means the session is over,
            // signed out elsewhere or expired. Say so rather than retrying.
            Keychain.delete("session_token")
            Keychain.delete("refresh_token")
            state = .signedOut
            return nil
        }
        return token
    }

    private func adopt(_ data: Data) async throws {
        struct Result: Decodable {
            struct Tokens: Decodable { let token: String; let refreshToken: String }
            let tokens: Tokens?
        }
        guard let tokens = try JSONDecoder().decode(Result.self, from: data).tokens else {
            throw SessionError.badResponse
        }
        Keychain.write("session_token", tokens.token)
        Keychain.write("refresh_token", tokens.refreshToken)
        if state != .signedIn {
            state = .signedIn
            Task { await loadAccount() }
        }
    }

    /// When a JWT stops being valid, read from its own payload.
    private static func expiry(of jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

extension Session: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

enum SessionError: LocalizedError {
    case badResponse, cancelled

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Signing in didn't finish. Try again."
        case .cancelled: return "Signing in was cancelled."
        }
    }
}

/// The two tokens, in the Keychain rather than in preferences.
enum Keychain {
    private static let service = "ADEVSTUDIO.PersonalOSHealth.session"

    static func read(_ key: String) -> String? {
        var result: AnyObject?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String) {
        delete(key)
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            // Readable once the phone has been unlocked after a restart, so a
            // sync after the first unlock of the day still has a session.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
