import Combine
import SwiftUI
import UserNotifications

/// Telling you a reading is ready.
@MainActor
final class Notifier: NSObject, ObservableObject {
    static let shared = Notifier()

    /// Set when a notification is tapped.
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

    /// Posts immediately — the work is already done, so there is nothing to schedule.
    func readingReady(specialist: String, window: String, opening: String) {
        let content = UNMutableNotificationContent()
        content.title = "Your \(specialist.lowercased()) has finished reading"
        content.subtitle = window
        content.body = opening
        content.sound = .default
        content.userInfo = ["route": "specialists"]

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "reading-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
        )
    }

    /// The first sentence of a report, as the notification body.
    static func opening(of report: String) -> String {
        let flat = report
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flat.isEmpty else { return "" }

        // Cut on a sentence, not on the first full stop.
        var first: String?
        flat.enumerateSubstrings(in: flat.startIndex..., options: [.bySentences]) { substring, _, _, stop in
            first = substring?.trimmingCharacters(in: .whitespaces)
            stop = true
        }
        let sentence = first ?? flat
        return sentence.count > 180 ? "Open to read it." : sentence
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
        await MainActor.run { Notifier.shared.opened = .specialists }
    }
}
