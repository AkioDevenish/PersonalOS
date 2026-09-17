import SwiftUI
import UIKit

/// Registering this device so the server can reach it.
///
/// The app's own notifications are local: they can only appear while it is
/// running, which is no use for the one thing worth telling somebody — that a
/// practitioner has replied, or that their article was verified, while they
/// were somewhere else entirely. Those are sent by Apple now, from
/// convex/push.ts, to the token registered here.
///
/// Nothing here works until the paid developer account exists: the Push
/// Notifications capability is not available to a free personal team, so
/// registration fails with an error that is recorded and otherwise ignored.
/// The day the capability is added, this starts working with no code change.
@MainActor
enum Push {
    private(set) static var token: String?
    private(set) static var failure: String?

    /// Asks Apple for a token, but only if notifications are already allowed.
    /// Registering is not a prompt; being asked out of nowhere on launch is.
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

    /// On sign-out, so the next person holding this phone is not sent
    /// somebody else's messages.
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
