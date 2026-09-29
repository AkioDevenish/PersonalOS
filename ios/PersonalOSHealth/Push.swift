import SwiftUI
import UIKit

/// Registering this device so the server can reach it.
@MainActor
enum Push {
    private(set) static var token: String?
    private(set) static var failure: String?

    /// Asks Apple for a token, but only if notifications are already allowed.
    static func registerIfAllowed() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func register() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func received(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        token = hex
        failure = nil
        Task { try? await DevicesClient().register(token: hex) }
    }

    static func failed(_ error: Error) {
        failure = error.localizedDescription
        token = nil
    }

    /// On sign-out, so the next person holding this phone is not sent somebody else's messages.
    static func handBack() async {
        guard let token else { return }
        try? await DevicesClient().unregister(token: token)
        self.token = nil
    }
}

/// The one thing SwiftUI has no hook for: Apple handing back a device token.
final class PushDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in Push.received(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in Push.failed(error) }
    }
}

struct DevicesClient {
    private let transport = Transport()

    func register(token: String) async throws {
        _ = try await transport.mutation("devices:register", ["token": token, "platform": "ios"])
    }

    func unregister(token: String) async throws {
        _ = try await transport.mutation("devices:unregister", ["token": token])
    }
}
