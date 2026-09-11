import Combine
import SwiftUI
import UserNotifications

/// Telling you a reading is ready.
///
/// A reading takes about a minute — longer on the server, where a local model
/// is doing real work — and the only thing the app did with that minute was
/// hold you on the screen watching a button say "Consulting…". Anything else
/// you did with your phone meant coming back to check.
///
/// So the app says when it's finished. One notification, for one thing: a
/// reading you asked for is written. Nothing here fires on its own schedule,
/// nothing markets, and permission is asked at the moment it would first be
/// used rather than at launch — a prompt on first open, before the app has
/// done anything for you, is a prompt you should say no to.
@MainActor
final class Notifier: NSObject, ObservableObject {
    static let shared = Notifier()

    /// Set when a notification is tapped. RootView watches it and opens what
    /// the notification announced, so the tap lands on the report rather than
    /// on whatever screen the app happened to be showing.
    @Published var opened: Route?

    private override init() { super.init() }

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// True when the app may post. Asks once, the first time a reading is
    /// requested; after that it reads whatever the answer was without asking
    /// again — including "no", which is an answer and not a thing to re-ask.
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

    /// Posts immediately — the work is already done, so there is nothing to
    /// schedule. A nil trigger delivers on the next run loop.
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
    ///
    /// Truncating mid-sentence would show someone half a claim about their own
    /// health on a lock screen, so this cuts at a full stop or not at all.
    static func opening(of report: String) -> String {
        let flat = report
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flat.isEmpty else { return "" }

        // Cut on a sentence, not on the first full stop. A decimal point is
        // the same character, so "You slept 7.2 hours" was being delivered to
        // a lock screen as "You slept 7." Foundation knows where a sentence
        // ends; a search for "." does not.
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
    /// Shown even with the app open. The reading takes a minute; you may well
    /// be somewhere else in the app when it lands, and a banner is how you
    /// find out without having stayed on the screen.
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
