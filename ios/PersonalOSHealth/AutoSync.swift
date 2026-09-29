import Foundation
import Combine
import HealthKit

/// Sending readings to your account, without being asked, ever.
@MainActor
final class AutoSync: ObservableObject {
    static let shared = AutoSync()

    /// Long enough that returning to the app repeatedly costs nothing, short enough that a day's
    /// figures are never stale by much.
    private static let interval: TimeInterval = 30 * 60

    @Published private(set) var running = false
    @Published private(set) var lastMessage: String?

    private var lastAttempt: Date?

    /// Set only after the backfill has actually succeeded, so a failed one is tried again next time
    /// rather than written off.
    private static let backfilledKey = "personal_os_backfilled"

    private init() {}

    var lastSynced: Date? {
        let at = UserDefaults.standard.double(forKey: "last_sync_at")
        return at > 0 ? Date(timeIntervalSince1970: at) : nil
    }

    /// Called when the app becomes active.
    func runIfDue(_ health: HealthKitManager) async {
        guard HKHealthStore.isHealthDataAvailable(), !running else { return }
        if let last = lastSynced, Date().timeIntervalSince(last) < Self.interval { return }
        if let attempt = lastAttempt, Date().timeIntervalSince(attempt) < 60 { return }
        await run(health)

        // Then the history, once, after today has gone up.
        guard !UserDefaults.standard.bool(forKey: Self.backfilledKey) else { return }
        if (try? await backfill(health)) != nil {
            UserDefaults.standard.set(true, forKey: Self.backfilledKey)
        }
    }

    /// Today, now.
    func run(_ health: HealthKitManager) async {
        guard !running else { return }
        running = true
        lastAttempt = Date()
        defer { running = false }
        do {
            // Asking is free once granted, and it is the only way to know the app still has access
            // after somebody changes their mind in Health.
            try await health.requestAuthorization()
            let snapshot = try await health.fetchTodaySnapshot()
            let result = try await IngestClient().upload(snapshot: snapshot)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_sync_at")
            _ = result
            lastMessage = nil
        } catch where !error.isCancellation {
            // Not shown as an alert.
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
