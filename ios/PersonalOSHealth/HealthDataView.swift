import SwiftUI

/// Where readings come from, and sending them to your account.
///
/// Moved out of Profile, where two sync buttons sat among account settings.
/// This is about data, so it is one row in Settings that opens onto all of it.
struct HealthDataView: View {
    @EnvironmentObject private var health: HealthKitManager
    @AppStorage("last_sync_at") private var lastSyncAt: Double = 0

    @State private var status = ""
    @State private var busy = false

    var body: some View {
        List {
            Section {
                Label("Apple Health", systemImage: "heart.text.square")
            } footer: {
                Text("The only source. Linking a watch or ring needed a web server to run the sign-in redirect and hold the provider's secret, so it is not here; Apple Health already carries what a watch records.")
            }

            Section {
                Button { Task { await sync(days: nil) } } label: {
                    Label(busy ? "Syncing…" : "Sync today", systemImage: "arrow.triangle.2.circlepath")
                }
                Button { Task { await sync(days: 30) } } label: {
                    Label("Send the last 30 days", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("Sync")
            } footer: {
                Text(status.isEmpty ? lastSynced : status)
            }
            .disabled(busy)
        }
        .navigationTitle("Health data")
    }

    private var lastSynced: String {
        guard lastSyncAt > 0 else { return "Not synced yet." }
        let when = Date(timeIntervalSince1970: lastSyncAt)
        return "Last synced \(when.formatted(.relative(presentation: .named)))."
    }

    private func sync(days: Int?) async {
        busy = true
        defer { busy = false }
        do {
            try await health.requestAuthorization()
            if let days {
                status = "Reading \(days) days from Apple Health…"
                let snapshots = try await health.fetchHistoricalSnapshots(days: days)
                status = "Sending \(snapshots.count) days…"
                let r = try await IngestClient().uploadHistory(snapshots: snapshots)
                lastSyncAt = Date().timeIntervalSince1970
                status = "Done: \(r.inserted) new, \(r.updated) updated."
            } else {
                let snapshot = try await health.fetchTodaySnapshot()
                let r = try await IngestClient().upload(snapshot: snapshot)
                lastSyncAt = Date().timeIntervalSince1970
                let n = (r.inserted ?? 0) + (r.updated ?? 0)
                status = "Synced \(n) measurements."
                if let rejected = r.rejected, let first = rejected.first {
                    status += " \(rejected.count) rejected: \(first.reason)"
                }
            }
        } catch {
            status = error.localizedDescription
        }
    }
}
