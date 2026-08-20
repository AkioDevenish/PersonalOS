import SwiftUI

/// Asking a person.
///
/// Every other screen in this app is a model reading numbers. This is the one
/// where a human answers, which makes it the one place the wording has to be
/// most careful: a question that has been sent and not yet read says "waiting",
/// in those words, and nothing anywhere claims it has been seen.
///
/// The readings are shown before they are sent, not after. Handing your glucose
/// and sleep to another person is the most consequential thing this app does,
/// and it should be a thing you did on purpose, having read what you were
/// handing over.
struct ConsultView: View {
    @EnvironmentObject var health: HealthKitManager
    @AppStorage(Cuisine.key) private var country = Cuisine.deviceDefault

    @State private var inbox = ConsultClient.Inbox.empty
    @State private var question = ""
    @State private var shareReadings = true
    @State private var today: HealthSnapshot?
    @State private var sending = false
    @State private var status = ""
    @State private var open: ConsultClient.Summary?
    /// Who you are asking. Nil until you pick, because "a nutritionist" is not
    /// a person and the price depends on which one.
    @State private var chosen: ConsultClient.Professional?

    /// The readings that would travel with the question, exactly as the
    /// nutritionist will see them.
    private var readings: String {
        guard let today else { return "" }
        return ["glucose", "carbs", "sleep", "active_energy", "steps", "resting_hr"]
            .compactMap { Metrics.by(id: $0) }
            .compactMap { spec in
                guard let shown = spec.display(today) else { return nil }
                let unit = spec.unit.isEmpty ? "" : " \(spec.unit)"
                return "\(spec.label): \(shown)\(unit)"
            }
            .joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Consult", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("Ask a nutritionist.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                    .flowIn(1)

                Text(inbox.professionals.isEmpty
                     ? "No nutritionist has taken this on yet. You can write your question and it will be waiting for the first one who does."
                     : "A person reads these, not a model. Answers come back here.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                // MARK: Who you're asking

                if !inbox.professionals.isEmpty {
                    SectionRule(text: "Who you're asking").padding(.top, 30)

                    VStack(spacing: 0) {
                        ForEach(inbox.professionals) { pro in
                            Button {
                                Haptics.select()
                                withAnimation(Theme.Motion.bouncy) {
                                    chosen = chosen?.id == pro.id ? nil : pro
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 10) {
                                        Text(pro.name)
                                            .font(Theme.serif(20))
                                            .foregroundStyle(chosen?.id == pro.id ? Theme.amber : Theme.ink)
                                        Spacer()
                                        Text(pro.price)
                                            .font(Theme.sans(9.5))
                                            .tracking(1.2)
                                            .foregroundStyle(Theme.dust)
                                        if chosen?.id == pro.id { SelectionMark(size: 12) }
                                    }
                                    Text([pro.credentials, pro.place]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "))
                                        .font(Theme.sans(10.5))
                                        .foregroundStyle(Theme.dust)
                                    if !pro.bio.isEmpty {
                                        Text(pro.bio)
                                            .font(Theme.serifBody(15.5))
                                            .foregroundStyle(Theme.mid)
                                            .lineSpacing(4)
                                            .multilineTextAlignment(.leading)
                                            .padding(.top, 2)
                                    }
                                }
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressRow)
                        }
                    }
                    .padding(.top, 6)
                    .flowIn(3)
                }

                // MARK: Asking

                TextEditor(text: $question)
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if question.isEmpty {
                            Text("What would you like to ask?")
                                .font(Theme.serifBody(17))
                                .foregroundStyle(Theme.dust)
                                .allowsHitTesting(false)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.top, 20)
                    .flowIn(3)

                if !readings.isEmpty {
                    Button {
                        Haptics.select()
                        withAnimation(Theme.Motion.bouncy) { shareReadings.toggle() }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: shareReadings ? "checkmark.circle" : "circle")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(shareReadings ? Theme.amber : Theme.dust)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Send today's readings with it")
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.mid)
                                if shareReadings {
                                    Text(readings)
                                        .font(Theme.sans(10.5))
                                        .foregroundStyle(Theme.dust)
                                        .lineSpacing(3)
                                        .transition(.opacity)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressRow)
                    .padding(.top, 8)
                    .flowIn(4)
                }

                Button {
                    Task { await ask() }
                } label: {
                    Text(sendLabel)
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSend ? Theme.ink : Theme.dust)
                        .clipShape(Capsule())
                        .contentTransition(.opacity)
                        .animation(Theme.Motion.flow, value: sending)
                }
                .buttonStyle(.press)
                .disabled(sending || !canSend)
                .padding(.top, 14)
                .flowIn(5)

                if !status.isEmpty {
                    Text(status)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                // MARK: What you've asked

                if !inbox.consults.isEmpty {
                    SectionRule(text: "Your questions").padding(.top, 34)

                    VStack(spacing: 0) {
                        ForEach(inbox.consults) { c in
                            Button {
                                open = c
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 10) {
                                        Text(c.topic)
                                            .font(Theme.serif(19))
                                            .foregroundStyle(Theme.ink)
                                        Spacer()
                                        Kicker(
                                            text: c.waiting ? "Waiting" : "Answered",
                                            color: c.waiting ? Theme.dust : Theme.sage,
                                            size: 9
                                        )
                                    }
                                    if !c.last_message.isEmpty {
                                        Text(c.last_message)
                                            .font(Theme.sans(11))
                                            .foregroundStyle(Theme.dust)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressRow)
                        }
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 40)
            }
            .animation(Theme.Motion.flow, value: inbox.consults)
            .animation(Theme.Motion.flow, value: status)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $open) { summary in
            ConsultThreadView(summary: summary) { Task { await load() } }
        }
    }

    /// Names the person and the price, so nothing is spent by surprise.
    private var sendLabel: String {
        if sending { return "Sending…" }
        guard let chosen else {
            return inbox.professionals.isEmpty ? "Leave the question" : "Choose a nutritionist"
        }
        return chosen.price_credits == 0
            ? "Send to \(chosen.name)"
            : "Send to \(chosen.name) · \(chosen.price)"
    }

    private var canSend: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty
            && (chosen != nil || inbox.professionals.isEmpty)
    }

    private func load() async {
        try? await health.requestAuthorization()
        today = try? await health.fetchTodaySnapshot()
        inbox = (try? await ConsultClient().inbox()) ?? inbox
    }

    private func ask() async {
        let text = question.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await ConsultClient().start(
                topic: "Nutrition",
                question: text,
                nutritionistId: chosen?.id,
                shared: shareReadings ? readings : nil,
                country: country.isEmpty ? nil : Cuisine.name(for: country)
            )
            question = ""
            status = chosen == nil
                ? "Saved. It goes to the first nutritionist who takes it."
                : "Sent to \(chosen!.name). The answer arrives here."
            await load()
        } catch {
            status = error.localizedDescription
        }
    }
}

/// One conversation.
struct ConsultThreadView: View {
    let summary: ConsultClient.Summary
    var onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var thread: ConsultClient.Thread?
    @State private var reply = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let thread {
                        if !thread.shared.isEmpty {
                            Plate {
                                VStack(alignment: .leading, spacing: 6) {
                                    Kicker(text: "Readings you sent", size: 9)
                                    Text(thread.shared)
                                        .font(Theme.sans(10.5))
                                        .foregroundStyle(Theme.dust)
                                        .lineSpacing(3)
                                }
                            }
                            .padding(.top, 12)
                        }

                        ForEach(thread.messages) { m in
                            VStack(alignment: .leading, spacing: 6) {
                                Kicker(
                                    text: m.fromProfessional ? "Nutritionist" : "You",
                                    color: m.fromProfessional ? Theme.amber : Theme.dust,
                                    size: 9
                                )
                                Text(m.body)
                                    .font(Theme.serifBody(17))
                                    .foregroundStyle(m.fromProfessional ? Theme.ink : Theme.mid)
                                    .lineSpacing(6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                        }

                        if thread.messages.allSatisfy({ !$0.fromProfessional }) {
                            Text("No answer yet. You'll see it here when it comes.")
                                .font(Theme.sans(11.5))
                                .foregroundStyle(Theme.dust)
                                .padding(.top, 6)
                        }

                        HStack(spacing: 12) {
                            TextField("Add to your question", text: $reply, axis: .vertical)
                                .font(Theme.serifBody(17))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1...5)
                            Button {
                                Task { await send() }
                            } label: {
                                Kicker(text: sending ? "…" : "Send", color: Theme.amber, size: 10)
                            }
                            .buttonStyle(.press)
                            .disabled(sending || reply.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.vertical, 18)
                    } else {
                        Composing(lines: 3).padding(.top, 30)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .background(Theme.linen)
            .navigationTitle(summary.topic)
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        thread = try? await ConsultClient().thread(id: summary.id)
    }

    private func send() async {
        let text = reply.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }
        reply = ""
        try? await ConsultClient().reply(id: summary.id, body: text)
        await load()
        onChange()
    }
}
