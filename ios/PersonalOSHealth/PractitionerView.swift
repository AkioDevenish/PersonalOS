import SwiftUI

/// The other side of the desk.
///
/// Everything before this could list a practitioner, take their fee and open a
/// conversation with them — and they had no way to read a word of it. This is
/// where somebody answers.
///
/// It reuses the same chat and the same call the client sees, from the other
/// end, which is the point: one conversation with two people in it rather than
/// two systems that have to be kept in step.
struct PractitionerView: View {
    @State private var queue: [SpecialistsClient.Consultation] = []
    @State private var loading = true
    @State private var failure: String?
    @State private var calling: SpecialistsClient.Consultation?

    private let client = SpecialistsClient()

    private var waiting: [SpecialistsClient.Consultation] { queue.filter(\.needs_reply) }
    private var answered: [SpecialistsClient.Consultation] { queue.filter { !$0.needs_reply } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your consultations")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 6)
                    .flowIn(0)

                Text(summary)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.mid)
                    .padding(.top, 10)
                    .flowIn(1)

                if let failure {
                    Text(failure)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.amber)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 22)
                }

                if loading && queue.isEmpty {
                    Composing(lines: 3)
                        .frame(height: 84)
                        .padding(.top, 30)
                } else if queue.isEmpty && failure == nil {
                    empty
                } else {
                    if !waiting.isEmpty {
                        SectionRule(text: "Waiting on you")
                            .padding(.top, 36)
                            .padding(.bottom, 4)
                        ForEach(Array(waiting.enumerated()), id: \.element.id) { i, one in
                            row(one).flowIn(min(i, 6) + 2)
                        }
                    }
                    if !answered.isEmpty {
                        SectionRule(text: "Answered")
                            .padding(.top, 36)
                            .padding(.bottom, 4)
                        ForEach(Array(answered.enumerated()), id: \.element.id) { i, one in
                            row(one).flowIn(min(i, 6) + 2)
                        }
                    }
                }

                Ornament()
                    .padding(.top, 44)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .refreshable { await load() }
        .onAppear {
            guard queue.isEmpty else { return }
            Task { await load() }
        }
        .fullScreenCover(item: $calling) { one in
            VideoCallView(peer: "Your client", sessionId: one.id)
        }
    }

    private func row(_ one: SpecialistsClient.Consultation) -> some View {
        NavigationLink {
            // A practitioner reads the ledger they were sent; they do not get
            // a button that hands over their own.
            ChatView(peer: "Your client", sessionId: one.id, canShareReadings: false)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(one.topic)
                        .font(Theme.serif(20))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(one.asked.formatted(.dateTime.day().month(.abbreviated)))
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
                }

                if !one.last_message.isEmpty {
                    Text(one.last_message)
                        .font(Theme.sans(12.5))
                        .foregroundStyle(Theme.mid)
                        .lineLimit(2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }

                HStack(spacing: 8) {
                    if one.unpaid {
                        // Worth knowing before spending an hour on it.
                        tag("Unpaid", Theme.amber)
                    }
                    if one.isCall {
                        tag("Video", Theme.sage)
                    }
                    Spacer()
                    if one.isCall && !one.unpaid {
                        Button {
                            Haptics.tap()
                            calling = one
                        } label: {
                            Text("Join call")
                                .font(Theme.sans(11, medium: true))
                                .foregroundStyle(Theme.warm)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.ink, in: Capsule())
                        }
                        .buttonStyle(.press)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }

    private func tag(_ text: String, _ tint: Color) -> some View {
        Text(text)
            .font(Theme.sans(10, medium: true))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.16), in: Capsule())
    }

    private var summary: String {
        if loading && queue.isEmpty { return "Reading your queue" }
        let n = waiting.count
        if n == 0 { return "Nobody is waiting on you." }
        return "\(n) \(n == 1 ? "person is" : "people are") waiting on a reply, oldest first."
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Nothing yet")
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)
            Text("Consultations people book with you appear here.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.dust)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    private func load() async {
        loading = true
        failure = nil
        do {
            queue = try await client.queue()
        } catch where error.isCancellation {
            return
        } catch {
            failure = error.localizedDescription
        }
        loading = false
    }
}
