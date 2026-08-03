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
                            .buttonStyle(.plain)
                            Rule()
                        }
                    }
                    .padding(.top, 16)
                }

                Spacer(minLength: 40)
            }
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
                Text("❧").font(Theme.serif(13)).foregroundStyle(Theme.amber)
            }
            Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func detailLine(_ p: AIClient.Provider, stored: AIClient.StoredKey?) -> String {
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
            settings = try await AIClient().settings()
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

    private var hasKey: Bool { stored != nil || !provider.needsKey }

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

                    SecureField(placeholder, text: $entry)
                        .font(Theme.sans(13))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.vertical, 14)
                        .padding(.horizontal, 14)
                        .background(Theme.warm)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.hairline, lineWidth: 1))
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
                    }
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
                            Task { await use(model: m) }
                        } label: {
                            HStack {
                                Text(m)
                                    .font(Theme.serif(18))
                                    .foregroundStyle(isCurrent(m) ? Theme.amber : Theme.ink)
                                Spacer()
                                if isCurrent(m) {
                                    Text("❧").font(Theme.serif(13)).foregroundStyle(Theme.amber)
                                }
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasKey || isBusy)
                        .opacity(hasKey ? 1 : 0.4)
                        Rule()
                    }
                }
                .padding(.top, 16)

                if !hasKey {
                    Text("Add a key above to use these.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 12)
                }

                if stored != nil {
                    Button {
                        Task { await forget() }
                    } label: {
                        Kicker(text: "Remove this key", size: 10)
                    }
                    .padding(.top, 30)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholder: String {
        provider.keyPrefix.map { "\($0)…" } ?? "API key"
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
        do {
            try await AIClient().select(provider: provider.id, model: model)
            status = "Reports will use \(model)."
            await onChange()
            dismiss()
        } catch {
            status = error.localizedDescription
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
