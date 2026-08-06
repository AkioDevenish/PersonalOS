import SwiftUI
import ClerkKit
import ClerkKitUI

/// Settings: the ledger of providers, plus sync controls and the dev section.
struct ConnectionsView: View {
    @EnvironmentObject var health: HealthKitManager
    @Environment(Store.self) private var store
    @AppStorage("last_sync_at") private var lastSyncAt: Double = 0
    @Environment(Clerk.self) private var clerk
    @State private var status = ""
    @State private var isBusy = false
    @State private var showProfile = false
    @State private var showModels = false
    @State private var connections = ConnectionsClient()
    @State private var wearables: [ConnectionsClient.Connection] = []
    @State private var busyProvider: String?

    #if DEBUG
    @State private var debugURL = AppConfig.baseURL
    @State private var debugToken = DebugTokenAuthProvider.token
    #endif

    private var lastSyncLine: String {
        guard lastSyncAt > 0 else { return "never synced" }
        let d = Date(timeIntervalSince1970: lastSyncAt)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "synced \(f.localizedString(for: d, relativeTo: Date()))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Account", color: Theme.amber, size: 11)
                    .padding(.top, 8)

                // Who you are comes first; what you've connected follows.
                Button {
                    showProfile = true
                } label: {
                    HStack(spacing: 14) {
                        Avatar(user: clerk.user, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .font(Theme.serif(26))
                                .foregroundStyle(Theme.ink)
                            if let email = clerk.user?.emailAddresses.first?.emailAddress {
                                Text(email)
                                    .font(Theme.sans(11.5))
                                    .foregroundStyle(Theme.dust)
                            }
                        }
                        Spacer()
                        Text("›")
                            .font(Theme.serif(24))
                            .foregroundStyle(Theme.dust)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                SectionRule(text: "Connections")
                    .padding(.top, 30)

                VStack(spacing: 0) {
                    Rule()
                    providerRow("Apple Health", status: "Connected · \(lastSyncLine)", state: .connected)
                    Rule()
                    // Real rows now, from the server: whether the account is
                    // linked, when it last delivered, and whether this
                    // deployment even holds the credentials to offer a link.
                    ForEach(wearables) { c in
                        wearableRow(c)
                        Rule()
                    }
                }
                .padding(.top, 18)

                if wearables.contains(where: { !$0.configured }) {
                    Text("Greyed-out services need Personal OS registered as an app with that company first. The sync is written and waiting on the credentials.")
                        .font(Theme.sans(11.5))
                        .foregroundStyle(Theme.dust)
                        .lineSpacing(4)
                        .padding(.top, 16)
                }

                Text("When two devices report the same thing, we pick one and show you which — never both added together.")
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(4)
                    .padding(.top, 10)

                SectionRule(text: "Plan")
                    .padding(.top, 32)

                NavigationLink { PaywallView() } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(planTitle)
                                .font(Theme.serif(19))
                                .foregroundStyle(Theme.ink)
                            Text(planSubtitle)
                                .font(Theme.sans(10.5))
                                .foregroundStyle(Theme.dust)
                        }
                        Spacer()
                        Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                Rule()

                SectionRule(text: "Intelligence")
                    .padding(.top, 32)

                Button {
                    showModels = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Model and keys")
                                .font(Theme.serif(19))
                                .foregroundStyle(Theme.ink)
                            Text("Claude, ChatGPT, Kimi, Gemini or your own Mac")
                                .font(Theme.sans(10.5))
                                .foregroundStyle(Theme.dust)
                        }
                        Spacer()
                        Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                Rule()

                SectionRule(text: "Sync")
                    .padding(.top, 32)

                VStack(spacing: 12) {
                    actionButton(isBusy ? "Syncing…" : "Sync today to Personal OS") { await sync(days: nil) }
                    actionButton(isBusy ? "Working…" : "Backfill last 30 days") { await sync(days: 30) }
                }
                .padding(.top, 18)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                #if DEBUG
                SectionRule(text: "Debug — not in release")
                    .padding(.top, 32)
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Server URL", text: $debugURL)
                        .font(Theme.sans(13))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { AppConfig.baseURL = debugURL }
                    SecureField("Session token", text: $debugToken)
                        .font(Theme.sans(13))
                        .onSubmit { DebugTokenAuthProvider.token = debugToken }
                }
                .padding(.top, 14)
                #endif

                Button {
                    Task { try? await clerk.auth.signOut() }
                } label: {
                    Kicker(text: "Sign out", size: 11)
                }
                .padding(.top, 28)

                Text(buildStamp)
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await loadConnections() }
        .sheet(isPresented: $showProfile) { UserProfileView() }
        // Its own stack: the model list drills into a provider, and the tab
        // bar has no navigation of its own to borrow.
        .sheet(isPresented: $showModels) {
            NavigationStack { ModelSettingsView() }
        }
    }

    private var planTitle: String {
        if store.entitlement.isSubscribed { return "Subscribed" }
        if store.entitlement.credits > 0 { return "\(store.entitlement.credits) readings left" }
        return "Free"
    }

    private var planSubtitle: String {
        if store.entitlement.isSubscribed {
            return "Hosted readings, sync and wearables"
        }
        return "On-device readings and your own key · see plans"
    }

    /// Sage for a live connection, dust for one that isn't offered yet.
    /// Deliberately no amber: amber is the app's call-to-action colour, and
    /// using it for something unactionable is what made these look tappable.
    private enum ProviderState { case connected, unavailable }

    /// A wearable: tappable when it can actually do something, inert when it
    /// can't — and the row says which, rather than looking the same either way.
    @ViewBuilder
    private func wearableRow(_ c: ConnectionsClient.Connection) -> some View {
        let busy = busyProvider == c.key
        Button {
            Task { await act(on: c) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.label)
                        .font(Theme.serif(20))
                        .foregroundStyle(c.configured ? Theme.ink : Theme.mid)
                    if let err = c.last_error, !err.isEmpty, c.isConnected {
                        Text(err)
                            .font(Theme.sans(10))
                            .foregroundStyle(Theme.amber)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(wearableStatus(c, busy: busy))
                    .font(Theme.sans(11))
                    .foregroundStyle(wearableTint(c))
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!c.configured || busy)
    }

    private func wearableStatus(_ c: ConnectionsClient.Connection, busy: Bool) -> String {
        if busy { return c.isConnected ? "Syncing…" : "Connecting…" }
        if !c.configured { return "Not set up yet" }
        if c.isConnected {
            guard let t = c.last_sync_at, t > 0 else { return "Connected · tap to sync" }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "synced \(f.localizedString(for: Date(timeIntervalSince1970: t / 1000), relativeTo: Date()))"
        }
        return "CONNECT"
    }

    private func wearableTint(_ c: ConnectionsClient.Connection) -> Color {
        if !c.configured { return Theme.dust }
        return c.isConnected ? Theme.sage : Theme.amber
    }

    /// Connect if it isn't linked, sync if it is.
    private func act(on c: ConnectionsClient.Connection) async {
        guard c.configured else { return }
        busyProvider = c.key
        defer { busyProvider = nil }
        do {
            if c.isConnected {
                status = "\(c.label): \(try await connections.sync(c.key, days: 14))"
            } else {
                try await connections.connect(c.key)
                status = "\(c.label) connected. Pulling your history…"
                // A fresh link has nothing behind it until the first pull.
                status = "\(c.label): \(try await connections.sync(c.key, days: 30))"
            }
            await loadConnections()
        } catch ConnectionError.cancelled {
            status = ""
        } catch {
            status = error.localizedDescription
        }
    }

    private func loadConnections() async {
        wearables = (try? await connections.list()) ?? []
    }

    private func providerRow(_ name: String, status: String, state: ProviderState) -> some View {
        HStack {
            Text(name)
                .font(Theme.serif(20))
                .foregroundStyle(state == .connected ? Theme.ink : Theme.mid)
            Spacer()
            Text(status)
                .font(Theme.sans(11))
                .foregroundStyle(state == .connected ? Theme.sage : Theme.dust)
        }
        .padding(.vertical, 18)
    }

    private func actionButton(_ label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(label)
                .font(Theme.sans(13, medium: true))
                .foregroundStyle(Theme.warm)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.ink)
                .clipShape(Capsule())
        }
        .disabled(isBusy)
    }

    private func sync(days: Int?) async {
        isBusy = true
        defer { isBusy = false }
        // Deliberately does NOT write debugURL back: doing so on every sync
        // pinned whatever was on screen into UserDefaults, which then outranked
        // the build-time host forever. The field persists on submit only.
        do {
            try await health.requestAuthorization()
            if let days {
                status = "Reading \(days) days from Apple Health…"
                let snapshots = try await health.fetchHistoricalSnapshots(days: days)
                status = "Uploading \(snapshots.count) days…"
                let r = try await IngestClient().uploadHistory(snapshots: snapshots)
                lastSyncAt = Date().timeIntervalSince1970
                status = "Backfill complete: \(r.inserted) new, \(r.updated) updated."
            } else {
                let snapshot = try await health.fetchTodaySnapshot()
                let r = try await IngestClient().upload(snapshot: snapshot)
                if r.success {
                    lastSyncAt = Date().timeIntervalSince1970
                    let n = (r.inserted ?? 0) + (r.updated ?? 0)
                    status = "Synced \(n) measurements."
                    if let rej = r.rejected, !rej.isEmpty {
                        status += " \(rej.count) rejected: \(rej[0].reason)"
                    }
                } else {
                    status = r.error ?? "Upload failed"
                }
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private var displayName: String {
        guard let u = clerk.user else { return "Not signed in" }
        let name = [u.firstName, u.lastName].compactMap { $0 }.joined(separator: " ")
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return u.emailAddresses.first?.emailAddress ?? "Your account"
    }

    /// Answers "which build is this, and where is it pointed" without a
    /// debugger — the two questions that cost the most time to guess at.
    /// The server URL used to be appended here so I could tell which build was
    /// on the phone during development. It served its purpose and became a raw
    /// https:// address sitting under Sign out, which reads like a mistake.
    /// The version and build number are the part worth keeping.
    private var buildStamp: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }
}

/// Circular profile picture, falling back to the ledger mark so the row never
/// collapses while the image loads or when no photo has been set.
struct Avatar: View {
    let user: User?
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle().fill(Theme.linen)
            Circle().stroke(Theme.hairline, lineWidth: 1)

            if let user, user.hasImage, let url = URL(string: user.imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
                .clipShape(Circle())
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        Text("❧")
            .font(Theme.serif(size * 0.38))
            .foregroundStyle(Theme.amber)
    }
}
