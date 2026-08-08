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
    @State private var showConnections = false
    @State private var connections = ConnectionsClient()
    @State private var wearables: [ConnectionsClient.Connection] = []

    #if DEBUG
    @State private var debugURL = AppConfig.baseURL
    @State private var debugToken = DebugTokenAuthProvider.token
    #endif


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Account", color: Theme.amber, size: 11)
                    .padding(.top, 8)
                    .flowIn(0)

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
                .buttonStyle(.pressRow)
                .padding(.top, 12)
                .flowIn(1)

                SectionRule(text: "Connections")
                    .padding(.top, 30)
                    .flowIn(2)

                // One row into its own screen, the same as Model and keys. The
                // full list lived inline here and turned Settings into a wall
                // — and made connections read as a different kind of thing
                // from models, which they aren't.
                Button {
                    showConnections = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sources")
                                .font(Theme.serif(19))
                                .foregroundStyle(Theme.ink)
                            Text(connectionsSubtitle)
                                .font(Theme.sans(10.5))
                                .foregroundStyle(Theme.dust)
                        }
                        Spacer()
                        Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressRow)
                .padding(.top, 6)

                SectionRule(text: "Plan")
                    .padding(.top, 32)
                    .flowIn(3)

                NavigationLink(value: Route.paywall) {
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
                .buttonStyle(.pressRow)
                .padding(.top, 6)

                SectionRule(text: "Intelligence")
                    .padding(.top, 32)
                    .flowIn(4)

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
                .buttonStyle(.pressRow)
                .padding(.top, 6)

                SectionRule(text: "Sync")
                    .padding(.top, 32)
                    .flowIn(5)

                VStack(spacing: 12) {
                    actionButton(isBusy ? "Syncing…" : "Sync today to Personal OS") { await sync(days: nil) }
                    actionButton(isBusy ? "Working…" : "Backfill last 30 days") { await sync(days: 30) }
                }
                .padding(.top, 18)
                .flowIn(6)

                if !status.isEmpty {
                    // Sync writes here as it goes; the line should arrive the
                    // way everything else on the screen does.
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .offset(y: -6)))
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
                .buttonStyle(.press)
                .padding(.top, 28)

                Text(buildStamp)
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
            }
            // Status arrives and disappears as a sync runs, which moves
            // everything under it. Animating on the value rather than at each
            // assignment keeps that one line from being written in six places.
            .animation(Theme.Motion.flow, value: status)
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
        .sheet(isPresented: $showConnections) {
            NavigationStack { ConnectionsListView() }
        }
    }

    /// Reads as a summary of the screen behind it, so the row is worth
    /// something before it's tapped.
    private var connectionsSubtitle: String {
        let linked = wearables.filter(\.isConnected).count
        if linked == 0 { return "Apple Health · connect a watch or ring" }
        return "Apple Health and \(linked) more"
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






    private func loadConnections() async {
        wearables = (try? await connections.list()) ?? []
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
                .contentTransition(.opacity)
                .animation(Theme.Motion.flow, value: isBusy)
        }
        .buttonStyle(.press)
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
