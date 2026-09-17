import SwiftUI

/// Where readings come from, and when they last went up.
///
/// This had two buttons on it. Syncing is not something anybody wants to do,
/// it is something they want to have happened, so it happens by itself when
/// the app opens and this screen only reports it. What is left is a backfill,
/// which is a real request: it reaches back past today.
struct HealthDataView: View {
    @EnvironmentObject private var health: HealthKitManager
    @ObservedObject private var sync = AutoSync.shared

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
                HStack {
                    Text("Automatic")
                    Spacer()
                    Text(sync.running ? "Syncing…" : lastSynced)
                        .foregroundStyle(Theme.secondaryText)
                }
                Button { Task { await backfill() } } label: {
                    Label(busy ? "Sending…" : "Send the last 30 days", systemImage: "clock.arrow.circlepath")
                }
                .disabled(busy || sync.running)
            } header: {
                Text("Sync")
            } footer: {
                Text(footer)
            }
        }
        .navigationTitle("Health data")
    }

    private var lastSynced: String {
        guard let at = sync.lastSynced else { return "not yet" }
        return at.formatted(.relative(presentation: .named))
    }

    private var footer: String {
        if !status.isEmpty { return status }
        if let failure = sync.lastMessage { return failure }
        return "Today's readings go up on their own when you open the app, at most every half hour. Sending the last 30 days is for a phone you have just signed in to."
    }

    private func backfill() async {
        busy = true
        status = "Reading 30 days from Apple Health…"
        defer { busy = false }
        do {
            let result = try await sync.backfill(health)
            status = "Done: \(result.inserted) new, \(result.updated) updated."
        } catch {
            status = error.localizedDescription
        }
    }
}
