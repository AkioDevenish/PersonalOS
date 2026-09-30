import Foundation
import Combine
import Security
import AuthenticationServices
import CryptoKit
import UIKit

/// Who is signed in, run by this app rather than by a service.
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
    /// One refresh at a time: several requests arriving together should wait on the same renewal,
    /// not each spend the refresh token.
    private var refreshing: Task<String?, Never>?
    /// Held for as long as the sign-in sheet is up, since the system cancels one nobody holds.
    private var webAuth: ASWebAuthenticationSession?
    /// Apple's own sheet, and who is waiting on it, for the same reason.
    private var appleAuth: ASAuthorizationController?
    private var appleAnswer: CheckedContinuation<ASAuthorization, Error>?

    private let transport = Transport()

    // MARK: Starting up

    /// On launch: signed in if a refresh token is on the device and the server has not refused it,
    /// signed out otherwise.
    func restore() async {
        guard refreshToken != nil else { state = .signedOut; return }
        _ = await validToken()
        // A refresh that failed for want of a network keeps the tokens, and the next request tries
        // again; only a refused one has already cleared them.
        guard refreshToken != nil else { state = .signedOut; return }
        state = .signedIn
        await loadAccount()
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

    /// Signs in with Google, Facebook or Apple. Apple uses its own sheet where the build allows it.
    func signIn(with provider: Provider) async throws {
        if provider == .apple && AppConfig.appleSignInSheet {
            do {
                try await signInWithAppleSheet()
                return
            } catch let error as ASAuthorizationError where error.code == .canceled {
                throw SessionError.cancelled
            } catch {
                // A build without the Sign in with Apple entitlement cannot show Apple's sheet; the
                // browser route still works when the deployment has Apple's web credentials.
                guard await providers().apple else { throw error }
            }
        }
        try await signInInBrowser(with: provider)
    }

    /// Apple's own sheet: no browser, and Apple signs a token the server checks for itself.
    private func signInWithAppleSheet() async throws {
        let nonce = Self.makeNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple puts this hash in the token; the server hashes the nonce itself and compares.
        request.nonce = Self.sha256Hex(nonce)

        defer { appleAuth = nil; appleAnswer = nil }
        let authorization: ASAuthorization = try await withCheckedThrowingContinuation { answer in
            appleAnswer = answer
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            appleAuth = controller
            controller.performRequests()
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw SessionError.badResponse
        }
        var params: [String: Any] = ["identityToken": identityToken, "nonce": nonce]
        // Apple gives the name once, on the first sign-in, and never puts it in the token.
        if let parts = credential.fullName {
            let name = PersonNameComponentsFormatter().string(from: parts).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { params["name"] = name }
        }
        let data = try await transport.anonymous("action", "auth:signIn", [
            "provider": "apple-native", "params": params,
        ])
        try await adopt(data)
    }

    /// A one-off value that ties Apple's token to this request.
    static func makeNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Opens the provider in a secure browser sheet, which closes the moment it is sent back to the
    /// app with a one-time code; that code, with the verifier from the first step, is exchanged for
    /// tokens.
    private func signInInBrowser(with provider: Provider) async throws {
        struct Started: Decodable { let redirect: String; let verifier: String }
        let data = try await transport.anonymous("action", "auth:signIn", [
            "provider": provider.rawValue,
            "params": ["redirectTo": "personalos://auth"],
        ])
        let started = try JSONDecoder().decode(Started.self, from: data)
        guard let url = URL(string: started.redirect) else { throw SessionError.badResponse }

        defer { webAuth = nil }
        let callback: URL = try await withCheckedThrowingContinuation { done in
            let sheet = ASWebAuthenticationSession(url: url, callbackURLScheme: "personalos") { url, error in
                if let url { done.resume(returning: url) }
                else { done.resume(throwing: error ?? SessionError.cancelled) }
            }
            sheet.presentationContextProvider = self
            // Remembers somebody already signed in to Google in the browser, so they are not asked
            // for their password again.
            sheet.prefersEphemeralWebBrowserSession = false
            webAuth = sheet
            if !sheet.start() { done.resume(throwing: SessionError.badResponse) }
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
        // Ends the session on the server too, so the refresh token on this phone stops being worth
        // anything even if it were copied.
        _ = try? await transport.action("auth:signOut")
        endSession()
    }

    // MARK: The account

    /// Deletes the account on the server, then forgets it here.
    func deleteAccount() async throws {
        _ = try await transport.mutation("users:deleteAccount")
        LocalData.forget()
        endSession()
    }

    func loadAccount() async {
        guard let data = try? await transport.query("users:me") else { return }
        account = try? JSONDecoder().decode(Account.self, from: data)
        if let account { LocalData.claim(for: account.id) }
    }

    private func endSession() {
        Keychain.delete("session_token")
        Keychain.delete("refresh_token")
        account = nil
        state = .signedOut
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
        let data: Data
        do {
            data = try await transport.anonymous("action", "auth:signIn", ["refreshToken": refreshToken])
        } catch {
            // Only the server refusing the token ends the session; a network that did not answer
            // keeps it for the next try.
            if Self.isRefusal(error) { endSession() }
            return nil
        }
        do {
            try await adopt(data)
        } catch {
            // No tokens back means the refresh token no longer works: signed out elsewhere, or expired.
            endSession()
            return nil
        }
        return token
    }

    /// Whether the server answered and said no, as opposed to not answering.
    static func isRefusal(_ error: Error) -> Bool {
        switch error {
        case TransportError.server: return true
        case TransportError.http(let code, _): return (400..<500).contains(code) && code != 408 && code != 429
        default: return false
        }
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
    static func expiry(of jwt: String) -> Date? {
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

extension Session: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated { appleAnswer?.resume(returning: authorization); appleAnswer = nil }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated { appleAnswer?.resume(throwing: error); appleAnswer = nil }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { keyWindow }
    }
}

extension Session: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { keyWindow }
    }

    /// Where a sign-in sheet hangs from.
    fileprivate var keyWindow: ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) { return key }
        // Sign-in only starts from a tap, so there is always a scene to hang a window on.
        return ASPresentationAnchor(windowScene: scenes[0])
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

/// What this phone keeps for the account signed in on it, apart from the tokens.
enum LocalData {
    private static let ownerKey = "personal_os_local_owner"

    /// Records whose data this is, clearing the last account's first if it was somebody else's.
    @MainActor
    static func claim(for accountId: String) {
        let owner = UserDefaults.standard.string(forKey: ownerKey)
        if let owner, owner != accountId { forget() }
        UserDefaults.standard.set(accountId, forKey: ownerKey)
    }

    /// Readings, saved chats and sync progress, all tied to one account.
    @MainActor
    static func forget() {
        Readings.shared.removeAll()
        Chats.shared.removeAll()
        AppConfig.syncCursor = nil
        for key in [ownerKey, "last_sync_at", AutoSync.backfilledKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

/// The two tokens, in the Keychain rather than in preferences.
enum Keychain {
    private static let service = "com.adevstudio.forklore.session"

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
            // Readable once the phone has been unlocked after a restart, so a sync after the first
            // unlock of the day still has a session.
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
