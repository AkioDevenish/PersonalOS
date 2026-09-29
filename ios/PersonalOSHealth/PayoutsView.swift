import SwiftUI

/// Being paid.
struct PayoutsView: View {
    @State private var status = Status(started: false, ready: false, feePercent: 15)
    @State private var working = false
    @State private var failure: String?

    @Environment(\.openURL) private var openURL

    struct Status: Decodable {
        let started: Bool
        let ready: Bool
        let feePercent: Double
    }

    private let transport = Transport()

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(status.ready ? "Ready" : status.started ? "Being checked" : "Not set up")
                        .foregroundStyle(status.ready ? Theme.positive : Theme.secondaryText)
                }
                Button {
                    Task { await open() }
                } label: {
                    Label(
                        working ? "Opening Stripe…"
                            : status.started ? "Continue with Stripe" : "Set up payouts",
                        systemImage: "building.columns"
                    )
                }
                .disabled(working)
                if status.started && !status.ready {
                    Button { Task { await refresh() } } label: {
                        Label("Check again", systemImage: "arrow.clockwise")
                    }
                    .disabled(working)
                }
            } header: {
                Text("Stripe")
            } footer: {
                Text(footer)
            }

            if let failure {
                Section { Text(failure).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Getting paid")
        .task { await refresh() }
    }

    private var footer: String {
        let share = status.feePercent.formatted(.number.precision(.fractionLength(0...1)))
        if status.ready {
            return "Clients pay you directly. Forklore keeps \(share)%."
        }
        if status.started {
            return "Stripe is still checking your details."
        }
        return "Set this up to take paid consultations. Your bank details go to Stripe, not us. Forklore keeps \(share)%."
    }

    private func open() async {
        working = true
        failure = nil
        defer { working = false }
        do {
            struct Link: Decodable { let url: String }
            let data = try await transport.action("payouts:link")
            guard let url = URL(string: try JSONDecoder().decode(Link.self, from: data).url) else {
                throw TransportError.badResponse
            }
            openURL(url)
        } catch {
            failure = error.localizedDescription
        }
    }

    private func refresh() async {
        // What Stripe says, then what we have recorded, so a practitioner who has just finished
        // onboarding sees it without waiting for a webhook.
        _ = try? await transport.action("payouts:refresh")
        if let data = try? await transport.query("payoutsData:mine"),
           let fresh = try? JSONDecoder().decode(Status.self, from: data) {
            status = fresh
        }
    }
}
