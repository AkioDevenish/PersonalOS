import Combine
import SwiftUI
import UserNotifications

/// Notification permission, and opening the right tab when one is tapped.
@MainActor
final class Notifier: NSObject, ObservableObject {
    static let shared = Notifier()

    /// Set when a practitioner-reply notification is tapped.
    @Published var opened: Route?

    private override init() { super.init() }

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// True when the app may post.
    func permitted() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// Shown even with the app open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let route = response.notification.request.content.userInfo["route"] as? String
        guard route == "specialists" else { return }
        await MainActor.run { Notifier.shared.opened = .professionals }
    }
}
