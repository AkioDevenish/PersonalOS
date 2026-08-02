import SwiftUI

/// There is no setup here any more.
///
/// The server URL, ingest token, user id and workspace id fields are gone: the
/// URL is baked into the build and identity comes from the signed-in session.
/// What's left is the two things a user genuinely has to do once — allow
/// Health access, and sync — plus a debug section that never ships.
struct ContentView: View {
    @StateObject private var health = HealthKitManager()
    @State private var status = "Allow Health access to start syncing."
    @State private var isBusy = false
    @State private var lastSync: Date?
    @State private var isSignedIn = Auth.provider.isSignedIn

    #if DEBUG
    @State private var debugBaseURL = AppConfig.baseURL
    @State private var debugToken = DebugTokenAuthProvider.token
    #endif

    var body: some View {
        NavigationStack {
            Form {
                if !isSignedIn {
                    Section {
                        Label("Not signed in", systemImage: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                        Text("Sign in with the same account you use on the web, and your health data starts flowing on its own.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Health") {
                    Button {
                        Task { await authorize() }
                    } label: {
                        Label("Allow Health access", systemImage: "heart.text.square")
                    }
                    .disabled(isBusy)

                    Button {
                        Task { await sync() }
                    } label: {
                        Label(isBusy ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isBusy || !isSignedIn)

                    Button {
                        Task { await syncHistory(days: 30) }
                    } label: {
                        Label(isBusy ? "Backfilling…" : "Backfill last 30 days", systemImage: "calendar.badge.clock")
                    }
                    .disabled(isBusy || !isSignedIn)

                    if let lastSync {
                        Text("Last sync: \(lastSync.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Status") {
                    Text(status).font(.footnote)
                }

                #if DEBUG
                Section("Debug — not in release builds") {
                    TextField("Server URL", text: $debugBaseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .onSubmit { AppConfig.baseURL = debugBaseURL }
                    SecureField("Session token (until Clerk SDK is added)", text: $debugToken)
                        .onSubmit {
                            DebugTokenAuthProvider.token = debugToken
                            isSignedIn = Auth.provider.isSignedIn
                        }
                    Text("Release builds use \(AppConfig.productionBaseURL) and the signed-in session.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                #endif
            }
            .navigationTitle("Personal OS Health")
            .refreshable { isSignedIn = Auth.provider.isSignedIn }
        }
    }

    private func authorize() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await health.requestAuthorization()
            status = "Health access granted. Your data will sync automatically."
        } catch {
            status = error.localizedDescription
        }
    }

    private func persistDebugSettings() {
        #if DEBUG
        AppConfig.baseURL = debugBaseURL
        DebugTokenAuthProvider.token = debugToken
        isSignedIn = Auth.provider.isSignedIn
        #endif
    }

    private func sync() async {
        isBusy = true
        defer { isBusy = false }
        persistDebugSettings()
        do {
            try await health.requestAuthorization()
            let snapshot = try await health.fetchTodaySnapshot()
            let response = try await IngestClient().upload(snapshot: snapshot)

            if response.success {
                lastSync = Date()
                let n = (response.inserted ?? 0) + (response.updated ?? 0)
                var line = "Synced \(n) measurements."
                // surface rejections rather than letting a bad mapping fail quietly
                if let rejected = response.rejected, !rejected.isEmpty {
                    line += " \(rejected.count) rejected: \(rejected[0].reason)"
                }
                status = line
            } else {
                status = response.error ?? "Upload failed"
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private func syncHistory(days: Int) async {
        isBusy = true
        defer { isBusy = false }
        persistDebugSettings()
        do {
            try await health.requestAuthorization()
            status = "Reading \(days) days from Apple Health…"
            let snapshots = try await health.fetchHistoricalSnapshots(days: days)
            status = "Uploading \(snapshots.count) days…"
            let result = try await IngestClient().uploadHistory(snapshots: snapshots)
            lastSync = Date()
            status = "Backfill complete: \(result.inserted) new, \(result.updated) updated across \(snapshots.count) days."
        } catch {
            status = error.localizedDescription
        }
    }
}
