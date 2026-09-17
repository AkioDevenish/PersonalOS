import Foundation
import Combine
import HealthKit

/// Sending today's readings to your account, without being asked.
///
/// There were two buttons for this, and a button is the wrong shape for it: a
/// sync is not a thing anybody wants, it is a thing they want to have
/// happened. It runs when the app comes to the front now, and the screen only
/// reports when it last did.
///
/// Throttled, because coming back to the app four times in a minute is
/// ordinary and four uploads of the same day is not. Silent, because a sync
/// nobody asked for should not interrupt them to say it worked; a failure is
/// left in `lastMessage` for the Health data screen, which is where somebody
/// looks when they wonder.
@MainActor
final class AutoSync: ObservableObject {
    static let shared = AutoSync()

    /// Long enough that returning to the app repeatedly costs nothing, short
    /// enough that a day's figures are never stale by much.
    private static let interval: TimeInterval = 30 * 60

    @Published private(set) var running = false
    @Published private(set) var lastMessage: String?

    private var lastAttempt: Date?

    private init() {}

    var lastSynced: Date? {
        let at = UserDefaults.standard.double(forKey: "last_sync_at")
        return at > 0 ? Date(timeIntervalSince1970: at) : nil
    }

    /// Called when the app becomes active. Does nothing most times it is
    /// called, which is the point.
    func runIfDue(_ health: HealthKitManager) async {
        guard HKHealthStore.isHealthDataAvailable(), !running else { return }
        if let last = lastSynced, Date().timeIntervalSince(last) < Self.interval { return }
        if let attempt = lastAttempt, Date().timeIntervalSince(attempt) < 60 { return }
        await run(health)
    }

    /// Today, now. Used by the screen's own button and by `runIfDue`.
    func run(_ health: HealthKitManager) async {
        guard !running else { return }
        running = true
        lastAttempt = Date()
        defer { running = false }
        do {
            // Asking is free once granted, and it is the only way to know the
            // app still has access after somebody changes their mind in Health.
            try await health.requestAuthorization()
            let snapshot = try await health.fetchTodaySnapshot()
            let result = try await IngestClient().upload(snapshot: snapshot)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_sync_at")
            _ = result
            lastMessage = nil
        } catch where !error.isCancellation {
            // Not shown as an alert. A sync nobody asked for that fails is not
            // an interruption; it is a line on the screen that explains it.
            lastMessage = error.localizedDescription
        } catch {}
    }

    /// The whole month, for a phone that has just been signed in to.
    func backfill(_ health: HealthKitManager, days: Int = 30) async throws -> (inserted: Int, updated: Int) {
        running = true
        defer { running = false }
        try await health.requestAuthorization()
        let snapshots = try await health.fetchHistoricalSnapshots(days: days)
        let result = try await IngestClient().uploadHistory(snapshots: snapshots)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_sync_at")
        return result
    }
}
