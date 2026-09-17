import Foundation
import Combine
import HealthKit

/// Sending readings to your account, without being asked, ever.
///
/// There is no screen for this and no button. A sync is not a thing anybody
/// wants, it is a thing they want to have happened, and a settings row
/// offering to do it is the app admitting it might not have.
///
/// Two jobs. Today's figures go up whenever the app comes to the front,
/// throttled, because returning to it four times in a minute is ordinary and
/// four uploads of the same day is not. And once per install, in the
/// background, the last thirty days go up behind them, so a phone just signed
/// in to arrives with a history rather than a single day.
///
/// Silent throughout: a failure is retried on the next launch rather than
/// announced. Nothing was asked for, so nothing has to be reported.
@MainActor
final class AutoSync: ObservableObject {
    static let shared = AutoSync()

    /// Long enough that returning to the app repeatedly costs nothing, short
    /// enough that a day's figures are never stale by much.
    private static let interval: TimeInterval = 30 * 60

    @Published private(set) var running = false
    @Published private(set) var lastMessage: String?

    private var lastAttempt: Date?

    /// Set only after the backfill has actually succeeded, so a failed one is
    /// tried again next time rather than written off.
    private static let backfilledKey = "personal_os_backfilled"

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

        // Then the history, once, after today has gone up. Behind it rather
        // than before, so the figure somebody is looking at is the first
        // thing sent and thirty days of reading never delays it.
        guard !UserDefaults.standard.bool(forKey: Self.backfilledKey) else { return }
        if (try? await backfill(health)) != nil {
            UserDefaults.standard.set(true, forKey: Self.backfilledKey)
        }
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
    ///
    /// Re-sending is harmless: ingest upserts on
    /// (user, provider, metric, recorded_at), so a partial run can simply be
    /// repeated on the next launch.
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
