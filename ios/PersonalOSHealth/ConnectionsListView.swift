import SwiftUI

/// Where your readings come from.
///
/// Built to the same shape as the model picker: a header, one plate for the
/// state you'd want at a glance, then a ruled list that drills into each
/// source. Settings had grown a long inline block of provider rows, which made
/// the screen a wall — and made connections feel like a different kind of
/// thing from models, when they're the same kind of thing.
struct ConnectionsListView: View {
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("last_sync_at") private var lastSyncAt: Double = 0

    @State private var client = ConnectionsClient()
    @State private var wearables: [ConnectionsClient.Connection] = []
    @State private var status = ""
    @State private var loading = true

    private var connectedCount: Int {
        // Apple Health is always one; it's the phone itself.
        1 + wearables.filter(\.isConnected).count
    }

    private var appleHealthLine: String {
        guard lastSyncAt > 0 else { return "never synced" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "synced \(f.localizedString(for: Date(timeIntervalSince1970: lastSyncAt), relativeTo: Date()))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Connections", color: Theme.amber, size: 11)
                    .padding(.top, 12)

                Text("Where your\nreadings come from.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 8)

                Text("Connect a watch or ring and its measurements join the same ledger as your phone's.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)

                Plate {
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: "Connected", size: 9)
                        Text("\(connectedCount)")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text(connectedCount == 1 ? "source · this iPhone" : "sources")
                            .font(Theme.sans(10.5))
                            .foregroundStyle(Theme.dust)
                    }
                }
                .padding(.top, 20)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 16)
                }

                SectionRule(text: "Sources").padding(.top, 30)

                VStack(spacing: 0) {
                    Rule()
                    // Apple Health isn't a link — it's the device you're
                    // holding, and there's nothing to authorise.
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple Health")
                                .font(Theme.serif(19))
                                .foregroundStyle(Theme.ink)
                            Text("This iPhone · \(appleHealthLine)")
                                .font(Theme.sans(10.5))
                                .foregroundStyle(Theme.dust)
                        }
                        Spacer()
                        Text("❧").font(Theme.serif(13)).foregroundStyle(Theme.sage)
                    }
                    .padding(.vertical, 15)
                    Rule()

                    if loading && wearables.isEmpty {
                        Text("Reading…")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.dust)
                            .padding(.vertical, 18)
                        Rule()
                    }

                    ForEach(wearables) { c in
                        NavigationLink {
                            SourceDetailView(connection: c, client: client, onChange: { await load() })
                        } label: {
                            row(c)
                        }
                        .buttonStyle(.plain)
                        Rule()
                    }
                }
                .padding(.top, 16)

                Text("When two sources report the same thing, we pick one and show you which — never both added together.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(3)
                    .padding(.top, 16)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ c: ConnectionsClient.Connection) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(c.label)
                    .font(Theme.serif(19))
                    .foregroundStyle(c.configured ? Theme.ink : Theme.mid)
                Text(subtitle(c))
                    .font(Theme.sans(10.5))
                    .foregroundStyle(Theme.dust)
            }
            Spacer()
            if c.isConnected {
                Text("❧").font(Theme.serif(13)).foregroundStyle(Theme.sage)
            }
            Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func subtitle(_ c: ConnectionsClient.Connection) -> String {
        if !c.configured { return "Not set up yet" }
        if c.isConnected {
            guard let t = c.last_sync_at, t > 0 else { return "Connected" }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "synced \(f.localizedString(for: Date(timeIntervalSince1970: t / 1000), relativeTo: Date()))"
        }
        return "Tap to connect"
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            wearables = try await client.list()
            status = ""
        } catch {
            status = error.localizedDescription
        }
    }
}

/// One source: connect it, sync it, or read why it isn't offered.
private struct SourceDetailView: View {
    let connection: ConnectionsClient.Connection
    let client: ConnectionsClient
    let onChange: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(connection.label)
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)

                Text(blurb)
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)

                if connection.configured {
                    Button {
                        Task { await act() }
                    } label: {
                        Text(buttonLabel)
                            .font(Theme.sans(13, medium: true))
                            .foregroundStyle(Theme.warm)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.ink)
                            .clipShape(Capsule())
                    }
                    .disabled(isBusy)
                    .padding(.top, 22)

                    if !connection.isConnected {
                        Text("Opens \(connection.label)'s own sign-in page. Personal OS never sees your password.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.dust)
                            .lineSpacing(3)
                            .padding(.top, 12)
                    }
                }

                if let err = connection.last_error, !err.isEmpty {
                    Plate {
                        VStack(alignment: .leading, spacing: 6) {
                            Kicker(text: "Last error", size: 9)
                            Text(err)
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(3)
                        }
                    }
                    .padding(.top, 18)
                }

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 18)
                }

                SectionRule(text: "What it brings").padding(.top, 32)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(brings, id: \.self) { line in
                        HStack(alignment: .top, spacing: 9) {
                            Text("·").font(Theme.serif(15)).foregroundStyle(Theme.dust)
                            Text(line)
                                .font(Theme.serifBody(16))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .padding(.top, 14)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var blurb: String {
        if !connection.configured {
            return "Personal OS needs to be registered as an app with \(connection.label) before this can be linked. The sync is written and waiting on that."
        }
        if connection.isConnected {
            return "Connected. Syncing pulls the last two weeks; anything already recorded is left alone."
        }
        return "Sign in with \(connection.label) and its readings join your ledger."
    }

    private var buttonLabel: String {
        if isBusy { return connection.isConnected ? "Syncing…" : "Connecting…" }
        return connection.isConnected ? "Sync now" : "Connect \(connection.label)"
    }

    /// Set from the adapters in provider-pull.ts, so this doesn't promise
    /// anything the sync can't actually deliver.
    private var brings: [String] {
        switch connection.key {
        case "oura":
            return ["Sleep stages and efficiency", "Resting heart rate and HRV",
                    "Respiratory rate", "Steps, calories and distance"]
        case "whoop":
            return ["Sleep stages and efficiency", "Recovery HRV and resting heart rate",
                    "Blood oxygen", "Strain calories and average heart rate"]
        case "fitbit":
            return ["Sleep stages and efficiency", "Resting heart rate",
                    "Steps, calories and distance"]
        default:
            return ["Daily measurements"]
        }
    }

    private func act() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if connection.isConnected {
                status = try await client.sync(connection.key, days: 14)
            } else {
                try await client.connect(connection.key)
                status = "Connected. Pulling your history…"
                status = try await client.sync(connection.key, days: 30)
            }
            await onChange()
        } catch ConnectionError.cancelled {
            status = ""
        } catch {
            status = error.localizedDescription
        }
    }
}
