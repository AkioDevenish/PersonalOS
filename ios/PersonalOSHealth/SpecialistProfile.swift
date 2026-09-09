import SwiftUI

/// One specialist, and the two ways of reaching them.
///
/// The fee is stated here and taken here, before anything opens. Somebody
/// should never find out what a conversation cost by looking at their balance
/// afterwards.
struct SpecialistProfileView: View {
    let specialist: SpecialistsClient.Specialist

    @State private var opening: SessionClient.Kind?
    @State private var session: SessionClient.Opened?
    @State private var confirming: SessionClient.Kind?
    @State private var failure: String?

    private let client = SessionClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                portrait
                    .padding(.bottom, 20)
                    .flowIn(0)

                Text(specialist.name)
                    .font(Theme.serif(38))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .flowIn(0)

                Text(specialist.credentials)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.mid)
                    .padding(.top, 6)
                    .flowIn(1)

                Text(specialist.place)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
                    .padding(.top, 3)
                    .flowIn(1)

                if !specialist.specialties.isEmpty {
                    FlowRow(spacing: 6) {
                        ForEach(specialist.specialties, id: \.self) { s in
                            Text(s)
                                .font(Theme.sans(11, medium: true))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Theme.amber.opacity(0.18), in: Capsule())
                        }
                    }
                    .padding(.top, 22)
                    .flowIn(2)
                }

                if !specialist.bio.isEmpty {
                    Text(specialist.bio)
                        .font(Theme.serifBody(17))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)
                        .flowIn(3)
                }

                SectionRule(text: specialist.free ? "Free to talk to" : "What it costs")
                    .padding(.top, 40)
                    .flowIn(4)

                Text(costLine)
                    .font(Theme.sans(13))
                    .foregroundStyle(specialist.free ? Theme.sage : Theme.mid)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .flowIn(4)

                if let failure {
                    Text(failure)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.amber)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)
                }

                action(.text, "Start a chat", "bubble.left")
                    .padding(.top, 28)
                    .flowIn(5)

                if specialist.offers_video {
                    action(.video, "Start a video call", "video")
                        .padding(.top, 12)
                        .flowIn(6)
                }

                Ornament()
                    .padding(.top, 44)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Theme.linen)
        .navigationBarTitleDisplayMode(.inline)
        // A paid conversation is confirmed before the credits move. A free one
        // has nothing to confirm, so it simply opens.
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible
        ) {
            Button("Continue \u{00B7} \(specialist.price)") {
                if let kind = confirming { Task { await open(kind) } }
                confirming = nil
            }
            Button("Cancel", role: .cancel) { confirming = nil }
        }
        .fullScreenCover(item: $session) { opened in
            // A session that owes money does not open into the conversation.
            // Being able to talk first and settle later is not a payment flow,
            // it is an invoice nobody agreed to.
            if opened.owing {
                PaymentView(specialist: specialist, session: opened)
            } else if opened.kind == "video" {
                VideoCallView(specialist: specialist, session: opened)
            } else {
                ChatView(specialist: specialist, sessionId: opened.id)
            }
        }
    }

    /// Their face, or the initials standing in for one.
    ///
    /// The initials are drawn underneath rather than swapped in while loading:
    /// a placeholder that flashes on every appearance is worse than one that
    /// simply sits there until the photograph covers it.
    private var portrait: some View {
        ZStack {
            Circle().fill(Theme.amber.opacity(0.16))

            Text(
                specialist.name
                    .split(separator: " ")
                    .prefix(2)
                    .compactMap { $0.first.map(String.init) }
                    .joined()
            )
            .font(Theme.serif(30))
            .foregroundStyle(Theme.amber)

            if let link = specialist.photo_url, let url = URL(string: link) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .clipShape(Circle())
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
    }

    private var costLine: String {
        specialist.free
            ? "\(specialist.name) does not charge. Start a conversation whenever you like."
            : "\(specialist.price) for a conversation, paid to \(specialist.name) when it opens."
    }

    private var confirmTitle: String {
        confirming == .video
            ? "Start a video call with \(specialist.name)?"
            : "Start a chat with \(specialist.name)?"
    }

    private func action(_ kind: SessionClient.Kind, _ title: String, _ symbol: String) -> some View {
        Button {
            Haptics.tap()
            failure = nil
            if specialist.free {
                Task { await open(kind) }
            } else {
                confirming = kind
            }
        } label: {
            HStack(spacing: 9) {
                if opening == kind {
                    ProgressView().tint(Theme.warm)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .light))
                        .environment(\.symbolVariants, .none)
                    Text(title)
                }
            }
            .font(Theme.sans(15, medium: true))
            .foregroundStyle(Theme.warm)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(kind == .text ? Theme.ink : Theme.mid, in: Capsule())
        }
        .buttonStyle(.press)
        .disabled(opening != nil)
    }

    private func open(_ kind: SessionClient.Kind) async {
        opening = kind
        failure = nil
        do {
            session = try await client.open(
                specialistId: specialist.id,
                kind: kind,
                topic: specialist.specialties.first
            )
            Haptics.tap()
        } catch {
            failure = error.localizedDescription
        }
        opening = nil
    }
}

extension SessionClient.Opened: Identifiable {}

/// A written conversation.
///
/// Polled rather than pushed: the phone reaches Convex over HTTP, so there is
/// no subscription to hold open. Three seconds apart is close enough to feel
/// like a conversation, and it stops the moment the screen goes away.
struct ChatView: View {
    let specialist: SpecialistsClient.Specialist
    let sessionId: String

    @Environment(\.dismiss) private var dismiss

    @State private var thread = SessionClient.Thread.empty
    @State private var draft = ""
    @State private var sending = false
    @State private var failure: String?
    @State private var poller: Task<Void, Never>?

    private let client = SessionClient()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if thread.messages.isEmpty {
                            Text("Say what you would like to ask. \(specialist.name) will see your ledger only if you choose to share it.")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.dust)
                                .lineSpacing(4)
                                .padding(.top, 30)
                        }
                        ForEach(thread.messages) { message in
                            bubble(message).id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .onChange(of: thread.messages.count) { _, _ in
                    // Follow the conversation down as it grows.
                    if let last = thread.messages.last {
                        withAnimation(Theme.Motion.flow) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(Theme.linen)
        .task {
            await refresh()
            poller = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    await refresh()
                }
            }
        }
        .onDisappear { poller?.cancel() }
    }

    private var header: some View {
        HStack {
            Button("Close") { dismiss() }
                .font(Theme.sans(13))
                .foregroundStyle(Theme.dust)
                .buttonStyle(.press)
            Spacer()
            VStack(spacing: 1) {
                Text(specialist.name)
                    .font(Theme.serif(19))
                    .foregroundStyle(Theme.ink)
                Text(thread.status == "answered" ? "Replied" : "Waiting for a reply")
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
            }
            Spacer()
            // Balances the Close button so the name sits centred.
            Text("Close").font(Theme.sans(13)).opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(Theme.linen)
    }

    private func bubble(_ message: SessionClient.Message) -> some View {
        HStack {
            if !message.theirs { Spacer(minLength: 40) }
            Text(message.body)
                .font(Theme.sans(14))
                .foregroundStyle(message.theirs ? Theme.ink : Theme.warm)
                .lineSpacing(4)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    message.theirs ? Theme.warm : Theme.ink,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            if message.theirs { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.theirs ? .leading : .trailing)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if let failure {
                Text(failure)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            Rule()
            HStack(spacing: 12) {
                TextField("Write a message", text: $draft, axis: .vertical)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1...5)

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.warm)
                        .frame(width: 34, height: 34)
                        .background(ready ? Theme.ink : Theme.dust, in: Circle())
                }
                .buttonStyle(.press)
                .disabled(!ready || sending)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.linen)
    }

    private var ready: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    private func refresh() async {
        guard let fresh = try? await client.thread(id: sessionId) else { return }
        thread = fresh
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        sending = true
        failure = nil
        draft = ""
        do {
            try await client.send(id: sessionId, body: text)
            await refresh()
        } catch {
            failure = error.localizedDescription
            // Give it back rather than losing what they typed.
            draft = text
        }
        sending = false
    }
}

/// The call screen, with no call behind it yet.
///
/// The session, the room and the fee are all real — what is missing is a
/// service to carry the video, which needs an account and keys that do not
/// exist yet. Saying so plainly beats a button that spins forever, and it
/// means the day a provider is added, only this view changes.
struct VideoCallView: View {
    let specialist: SpecialistsClient.Specialist
    let session: SessionClient.Opened

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "video")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(Theme.dust)
                .environment(\.symbolVariants, .none)

            Text("The call cannot connect yet")
                .font(Theme.serif(28))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            Text("Your session with \(specialist.name) is booked and the room is reserved. Personal OS has no video service connected to carry the picture, so the call itself will not open until one is added.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.mid)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .padding(.horizontal, 34)

            if session.price_minor > 0 {
                Text("Nothing has been charged for this call, and the conversation stays open in writing.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                    .padding(.horizontal, 34)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Write instead")
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(.press)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.linen)
    }
}


/// Where money would change hands.
///
/// The price, the practitioner and the session are all real and recorded. What
/// is missing is a payment processor, which needs an account and keys that do
/// not exist yet. Saying so is better than a card form that collects details
/// and cannot do anything with them — and it is the one screen that changes
/// when a processor is chosen.
struct PaymentView: View {
    let specialist: SpecialistsClient.Specialist
    let session: SessionClient.Opened

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Kicker(text: "To pay")
            Text(session.price)
                .font(Theme.serif(52))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text("to \(specialist.name)")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.mid)
                .padding(.top, 6)

            Text("Personal OS has no payment processor connected, so this cannot be collected yet. Your conversation has been reserved and nothing has been charged to you.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.mid)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 30)
                .padding(.horizontal, 34)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(.press)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.linen)
    }
}
