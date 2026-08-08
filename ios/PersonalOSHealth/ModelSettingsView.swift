import SwiftUI

/// Choose which mind reads your data, and hand it your own key.
///
/// The list is deliberately flat: every platform is shown whether or not a key
/// exists for it, because "which of these could I use" is the question someone
/// opens this screen with. A stored key is shown only as its last four
/// characters — the server has no endpoint that returns more, so there is
/// nothing here that could display a full credential even by mistake.
struct ModelSettingsView: View {
    @State private var settings: AIClient.Settings?
    @State private var status = ""
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Intelligence", color: Theme.amber, size: 11)
                    .padding(.top, 12)

                Text("Which mind reads\nyour data.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 8)

                Text("Bring your own key. It's encrypted before it's stored, never shown back to you, and only ever used for your own reports.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)

                if let current = settings?.selection {
                    Plate {
                        VStack(alignment: .leading, spacing: 6) {
                            Kicker(text: "Currently using", size: 9)
                            Text(label(for: current.provider))
                                .font(Theme.serif(24))
                                .foregroundStyle(Theme.ink)
                            Text(current.model)
                                .font(Theme.sans(11.5))
                                .foregroundStyle(Theme.dust)
                        }
                    }
                    .padding(.top, 20)
                }

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 16)
                }

                SectionRule(text: "Platforms").padding(.top, 30)

                if loading {
                    Text("Reading your settings…")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 0) {
                        Rule()
                        ForEach(settings?.providers ?? []) { p in
                            NavigationLink {
                                ProviderDetailView(
                                    provider: p,
                                    stored: key(for: p.id),
                                    selection: settings?.selection,
                                    onChange: { await load() }
                                )
                            } label: {
                                row(p)
                            }
                            .buttonStyle(.pressRow)
                            Rule()
                        }
                    }
                    .padding(.top, 16)
                }

                Spacer(minLength: 40)
            }
            .animation(Theme.Motion.flow, value: status)
            .animation(Theme.Motion.bouncy, value: settings?.selection?.model)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ p: AIClient.Provider) -> some View {
        let stored = key(for: p.id)
        let isCurrent = settings?.selection?.provider == p.id
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(p.title)
                    .font(Theme.serif(19))
                    .foregroundStyle(isCurrent ? Theme.amber : Theme.ink)
                Text(detailLine(p, stored: stored))
                    .font(Theme.sans(10.5))
                    .foregroundStyle(Theme.dust)
            }
            Spacer()
            if isCurrent {
                SelectionMark()
            }
            Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func detailLine(_ p: AIClient.Provider, stored: AIClient.StoredKey?) -> String {
        if p.id == ModelChoice.deviceProvider {
            // The one entry whose readiness is a property of the phone rather
            // than of anything stored on a server.
            if #available(iOS 26.0, *) { return OnDeviceInsights.availability.explanation }
            return "Needs iOS 26 or later"
        }
        if !p.needsKey { return "Runs on your Mac · no key needed" }
        if let stored { return "Key ending \(stored.last4)" }
        return "No key yet"
    }

    private func key(for provider: String) -> AIClient.StoredKey? {
        settings?.keys.first { $0.provider == provider }
    }

    private func label(for provider: String) -> String {
        settings?.providers.first { $0.id == provider }?.title ?? provider
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let s = try await AIClient().settings()
            settings = s
            // Keep the offline mirror honest, so the next launch knows which
            // engine to use without waiting on this call.
            if let sel = s.selection { ModelChoice.adopt(provider: sel.provider, model: sel.model) }
            status = ""
        } catch {
            status = error.localizedDescription
        }
    }
}

/// One platform: its models, and the key that unlocks them.
private struct ProviderDetailView: View {
    let provider: AIClient.Provider
    let stored: AIClient.StoredKey?
    let selection: AIClient.Selection?
    let onChange: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entry = ""
    @State private var status = ""
    @State private var isBusy = false
    @State private var chosenModel = ""

    /// On-device is usable when the phone says so; everything else when a key
    /// is stored, or when it needs none at all.
    private var hasKey: Bool {
        if provider.id == ModelChoice.deviceProvider { return ModelChoice.deviceEngineReady }
        return stored != nil || !provider.needsKey
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(provider.title)
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)

                if provider.needsKey {
                    SectionRule(text: stored == nil ? "Add a key" : "Replace the key")
                        .padding(.top, 26)

                    // A field still needs to read as somewhere you type, but a
                    // filled box was the wrong way to say it. A rule under the
                    // text says the same thing in this vocabulary.
                    VStack(spacing: 8) {
                        SecureField(placeholder, text: $entry)
                            .font(Theme.sans(13))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.vertical, 6)
                        Rule()
                    }
                    .padding(.top, 16)

                    if let stored {
                        Text("A key ending \(stored.last4) is already stored. Typing a new one replaces it.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.dust)
                            .lineSpacing(3)
                            .padding(.top, 10)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isBusy ? "Checking with \(provider.label)…" : "Save and verify")
                            .font(Theme.sans(13, medium: true))
                            .foregroundStyle(Theme.warm)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(entry.isEmpty ? Theme.dust : Theme.ink)
                            .clipShape(Capsule())
                            .contentTransition(.opacity)
                            .animation(Theme.Motion.flow, value: isBusy)
                            // The fill goes live the moment the field has
                            // something in it, so the button looks ready before
                            // it is tapped rather than after.
                            .animation(Theme.Motion.flow, value: entry.isEmpty)
                    }
                    .buttonStyle(.press)
                    .disabled(entry.isEmpty || isBusy)
                    .padding(.top, 14)

                    Text("The key is checked against \(provider.label) before it's saved, so a typo is caught here rather than halfway through a report.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
                        .lineSpacing(3)
                        .padding(.top, 12)

                    if let console = provider.consoleURL, let url = URL(string: console) {
                        Link(destination: url) {
                            Kicker(text: "Get a key from \(provider.label)", color: Theme.amber, size: 10)
                        }
                        .padding(.top, 14)
                    }
                }

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 16)
                }

                SectionRule(text: "Models").padding(.top, 32)

                VStack(spacing: 0) {
                    Rule()
                    ForEach(provider.models, id: \.self) { m in
                        Button {
                            guard !isCurrent(m) else { return }
                            Haptics.select()
                            Task { await use(model: m) }
                        } label: {
                            HStack {
                                Text(m)
                                    .font(Theme.serif(18))
                                    .foregroundStyle(isCurrent(m) ? Theme.amber : Theme.ink)
                                Spacer()
                                if isCurrent(m) {
                                    SelectionMark()
                                }
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressRow)
                        .disabled(!hasKey || isBusy)
                        .opacity(hasKey ? 1 : 0.4)
                        Rule()
                    }
                }
                .padding(.top, 16)

                if !hasKey {
                    Text(provider.id == ModelChoice.deviceProvider
                         ? unavailableNote
                         : "Add a key above to use these.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
                        .lineSpacing(3)
                        .padding(.top, 12)
                }

                if provider.id == ModelChoice.deviceProvider && hasKey {
                    Text("Your readings never leave this iPhone. It's a smaller model than the hosted ones, so a hosted model will give a deeper read when you want one.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
                        .lineSpacing(3)
                        .padding(.top, 12)
                }

                if stored != nil {
                    Button {
                        Task { await forget() }
                    } label: {
                        Kicker(text: "Remove this key", size: 10)
                    }
                    .buttonStyle(.press)
                    .padding(.top, 30)
                }

                Spacer(minLength: 40)
            }
            .animation(Theme.Motion.flow, value: status)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholder: String {
        provider.keyPrefix.map { "\($0)…" } ?? "API key"
    }

    private var unavailableNote: String {
        if #available(iOS 26.0, *) { return OnDeviceInsights.availability.explanation }
        return "Needs iOS 26 or later."
    }

    private func isCurrent(_ model: String) -> Bool {
        selection?.provider == provider.id && selection?.model == model
    }

    private func save() async {
        isBusy = true
        status = "Checking the key with \(provider.label)…"
        defer { isBusy = false }
        do {
            let verified = try await AIClient().saveKey(provider: provider.id, apiKey: entry)
            entry = ""
            status = verified.map { "Verified against \($0). Pick a model below." }
                ?? "Key saved. Pick a model below."
            await onChange()
        } catch {
            status = error.localizedDescription
        }
    }

    private func use(model: String) async {
        isBusy = true
        defer { isBusy = false }
        // Local first: the choice must survive losing the network, and for the
        // on-device engine there is nothing the server is needed for anyway.
        ModelChoice.adopt(provider: provider.id, model: model)
        do {
            try await AIClient().select(provider: provider.id, model: model)
            status = "Reports will use \(model)."
            await onChange()
            dismiss()
        } catch {
            // The selection still holds on this phone; say so rather than
            // implying it didn't take.
            status = "Saved on this iPhone. Couldn't reach the server to sync it: \(error.localizedDescription)"
        }
    }

    private func forget() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AIClient().deleteKey(provider: provider.id)
            status = "Key removed."
            await onChange()
            dismiss()
        } catch {
            status = error.localizedDescription
        }
    }
}
