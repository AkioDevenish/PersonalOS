import SwiftUI
import ClerkKit
import ClerkKitUI

/// Settings: the ledger of providers, plus sync controls and the dev section.
struct ConnectionsView: View {
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("last_sync_at") private var lastSyncAt: Double = 0
    @Environment(Clerk.self) private var clerk
    @State private var status = ""
    @State private var isBusy = false

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
                Kicker(text: "Settings", color: Theme.amber, size: 11)
                    .padding(.top, 8)

                Text("Connections")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    Rule()
                    providerRow("Apple Health", status: "Connected · \(lastSyncLine)", connected: true)
                    Rule()
                    providerRow("Oura", status: "CONNECT", connected: false)
                    Rule()
                    providerRow("Whoop", status: "CONNECT", connected: false)
                    Rule()
                    providerRow("Fitbit", status: "CONNECT", connected: false)
                    Rule()
                }
                .padding(.top, 28)

                Text("When two devices report the same thing, we pick one and show you which — never both added together.")
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(4)
                    .padding(.top, 16)

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
    }

    private func providerRow(_ name: String, status: String, connected: Bool) -> some View {
        HStack {
            Text(name)
                .font(Theme.serif(20))
                .foregroundStyle(Theme.ink)
            Spacer()
            if connected {
                Text(status)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.sage)
            } else {
                Text(status)
                    .font(Theme.sans(10, medium: true))
                    .tracking(1.5)
                    .foregroundStyle(Theme.amber)
            }
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

    /// Answers "which build is this, and where is it pointed" without a
    /// debugger — the two questions that cost the most time to guess at.
    private var buildStamp: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let host = AppConfig.baseURL.replacingOccurrences(of: "http://", with: "")
        return "v\(version) (\(build)) · \(host)"
    }

    private var displayName: String {
        guard let u = clerk.user else { return "Not signed in" }
        let name = [u.firstName, u.lastName].compactMap { $0 }.joined(separator: " ")
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return u.emailAddresses.first?.emailAddress ?? "Your account"
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
