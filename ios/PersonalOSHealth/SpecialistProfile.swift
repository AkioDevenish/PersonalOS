import SwiftUI
import WebRTC

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
    @State private var sharing = false

    @EnvironmentObject private var health: HealthKitManager

    private let client = SessionClient()

    /// Messages grouped by the day they were sent, oldest first.
    ///
    /// A conversation with a practitioner is not read in one sitting: a reply
    /// can be a day later, and without a date the two halves read as one
    /// exchange that contradicts itself.
    private var days: [(day: Date, messages: [SessionClient.Message])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: thread.messages) {
            calendar.startOfDay(for: $0.at)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted { $0.at < $1.at }) }
    }

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
                        ForEach(days, id: \.day) { day, messages in
                            Text(dayLabel(day))
                                .font(Theme.sans(10, medium: true))
                                .tracking(1.6)
                                .foregroundStyle(Theme.dust)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)

                            ForEach(messages) { message in
                                bubble(message).id(message.id)
                            }
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
        .sheet(isPresented: $sharing) {
            ShareReadingsSheet(specialist: specialist) { text in
                try await client.send(id: sessionId, body: text)
                await refresh()
            }
            .environmentObject(health)
        }
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

            VStack(alignment: message.theirs ? .leading : .trailing, spacing: 4) {
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

                Text(message.at.formatted(date: .omitted, time: .shortened))
                    .font(Theme.sans(9.5))
                    .foregroundStyle(Theme.dust)
                    .padding(.horizontal, 4)
            }

            if message.theirs { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.theirs ? .leading : .trailing)
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
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
                // The reason this app exists: a practitioner reading what was
                // actually recorded rather than what somebody remembers.
                Button {
                    Haptics.tap()
                    sharing = true
                } label: {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Theme.amber)
                        .environment(\.symbolVariants, .none)
                }
                .buttonStyle(.press)

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

/// The call, drawn by this app.
///
/// No web view and no hosted interface: the two video tracks come out of our
/// own peer connection and are rendered here, so the screen belongs to the
/// app rather than to whoever was carrying the media.
struct VideoCallView: View {
    let specialist: SpecialistsClient.Specialist
    let session: SessionClient.Opened

    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: CallEngine

    init(specialist: SpecialistsClient.Specialist, session: SessionClient.Opened) {
        self.specialist = specialist
        self.session = session
        _engine = StateObject(wrappedValue: CallEngine(sessionId: session.id))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let remote = engine.remoteTrack {
                VideoTrackView(track: remote, fill: true)
                    .ignoresSafeArea()
            } else {
                waiting
            }

            VStack {
                header
                Spacer()
                controls
            }

            // Yourself, small, in the corner — and only once there is
            // somebody else to look at. Before that you are the whole screen,
            // which is what the waiting state is for.
            if engine.remoteTrack != nil, let local = engine.localTrack, engine.cameraOn {
                VStack {
                    HStack {
                        Spacer()
                        VideoTrackView(track: local, fill: true)
                            .frame(width: 104, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.trailing, 16)
                            .padding(.top, 74)
                    }
                    Spacer()
                }
            }
        }
        .task { await engine.start() }
        .onChange(of: engine.state) { _, state in
            if state == .ended { dismiss() }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 4) {
            Text(specialist.name)
                .font(Theme.serif(20))
                .foregroundStyle(.white)
            Text(status)
                .font(Theme.sans(11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 16)
    }

    private var status: String {
        switch engine.state {
        case .idle, .connecting: return "Connecting"
        case .ringing: return "Waiting for them to join"
        case .live: return "Connected"
        case .ended: return "Ended"
        case .failed(let why): return why
        }
    }

    /// Yourself, full screen, while there is nobody else yet.
    private var waiting: some View {
        ZStack {
            if let local = engine.localTrack, engine.cameraOn {
                VideoTrackView(track: local, fill: true).ignoresSafeArea()
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear, .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 12) {
                if case .failed(let why) = engine.state {
                    Image(systemName: "video.slash")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.7))
                        .environment(\.symbolVariants, .none)
                    Text(why)
                        .font(Theme.sans(13))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 44)
                } else {
                    ProgressView().tint(.white)
                }

                // Said before a call fails rather than after, since this is
                // the cause of most calls that cannot connect.
                if !engine.relayAvailable, engine.state != .live {
                    Text("No relay server is configured, so this will only connect if a direct route exists.")
                        .font(Theme.sans(10.5))
                        .foregroundStyle(Theme.amber.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 44)
                        .padding(.top, 6)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            circle(engine.micOn ? "mic" : "mic.slash", on: engine.micOn) { engine.toggleMic() }
            circle("phone.down", on: false, destructive: true) {
                engine.hangUp()
                dismiss()
            }
            circle(engine.cameraOn ? "video" : "video.slash", on: engine.cameraOn) { engine.toggleCamera() }
        }
        .padding(.bottom, 42)
    }

    private func circle(
        _ symbol: String,
        on: Bool,
        destructive: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(destructive ? .white : (on ? .black : .white))
                .frame(width: 58, height: 58)
                .background(
                    destructive ? Color.red : (on ? Color.white : Color.white.opacity(0.22)),
                    in: Circle()
                )
                .environment(\.symbolVariants, .none)
        }
        .buttonStyle(.press)
    }
}

/// One WebRTC track, rendered by Metal.
private struct VideoTrackView: UIViewRepresentable {
    let track: RTCVideoTrack
    var fill: Bool = true

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = fill ? .scaleAspectFill : .scaleAspectFit
        view.backgroundColor = .black
        track.add(view)
        context.coordinator.attached = track
        return view
    }

    func updateUIView(_ view: RTCMTLVideoView, context: Context) {
        // Swapping tracks without detaching the old one leaves it rendering
        // into a view nobody can see, and holding the camera open with it.
        guard context.coordinator.attached !== track else { return }
        context.coordinator.attached?.remove(view)
        track.add(view)
        context.coordinator.attached = track
    }

    static func dismantleUIView(_ view: RTCMTLVideoView, coordinator: Coordinator) {
        coordinator.attached?.remove(view)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var attached: RTCVideoTrack?
    }
}

/// Paying for a conversation.
///
/// The checkout itself belongs to the processor: a hosted page, opened in the
/// browser, where card details are typed somewhere that is built to receive
/// them and this app never sees them.
///
/// Coming back from that page proves nothing — it is a URL the payer could
/// type themselves, and both processors say plainly not to act on it. So the
/// screen asks the server, which asks the processor, and only an answer from
/// there opens the conversation.
struct PaymentView: View {
    let specialist: SpecialistsClient.Specialist
    let session: SessionClient.Opened

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var paid = false
    @State private var starting = false
    @State private var waiting = false
    @State private var failure: String?
    @State private var poller: Task<Void, Never>?

    private let client = SessionClient()

    var body: some View {
        Group {
            if paid {
                if session.kind == "video" {
                    VideoCallView(specialist: specialist, session: session)
                } else {
                    ChatView(specialist: specialist, sessionId: session.id)
                }
            } else {
                asking
            }
        }
        .onDisappear { poller?.cancel() }
    }

    private var asking: some View {
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

            Text(waiting
                 ? "Finish in the page that opened. This screen will move on by itself once the payment clears."
                 : "You will be taken to a secure page to pay. Your conversation opens as soon as it clears.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.mid)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)
                .padding(.horizontal, 34)

            if let failure {
                Text(failure)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.amber)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .padding(.horizontal, 34)
            }

            Spacer()

            Button {
                Task { await pay() }
            } label: {
                ZStack {
                    Text(waiting ? "Waiting for the payment" : "Pay \(session.price)")
                        .opacity(starting ? 0 : 1)
                    if starting { ProgressView().tint(Theme.warm) }
                }
                .font(Theme.sans(15, medium: true))
                .foregroundStyle(Theme.warm)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(waiting ? Theme.dust : Theme.ink, in: Capsule())
            }
            .buttonStyle(.press)
            .disabled(starting || waiting)
            .padding(.horizontal, 30)

            Button("Not now") { dismiss() }
                .font(Theme.sans(13))
                .foregroundStyle(Theme.dust)
                .buttonStyle(.press)
                .padding(.top, 18)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.linen)
    }

    private func pay() async {
        starting = true
        failure = nil
        do {
            let url = try await client.startPayment(id: session.id)
            openURL(url)
            waiting = true
            watch()
        } catch {
            failure = error.localizedDescription
        }
        starting = false
    }

    /// Asks every few seconds while this screen is up, and gives up after a
    /// few minutes rather than polling a payment nobody is going to finish.
    private func watch() {
        poller?.cancel()
        poller = Task {
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if await client.isPaid(id: session.id) {
                    Haptics.tap()
                    withAnimation(Theme.Motion.settle) { paid = true }
                    return
                }
            }
            waiting = false
        }
    }
}

/// Handing your readings to a practitioner.
///
/// The whole text is shown before anything is sent, and it is sent verbatim.
/// What the practitioner reads is exactly what was on this screen when the
/// person agreed to it — no summary made afterwards, no field they did not
/// see. That is the difference between sharing health data and leaking it.
struct ShareReadingsSheet: View {
    let specialist: SpecialistsClient.Specialist
    let send: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var health: HealthKitManager

    @State private var snapshot: HealthSnapshot?
    @State private var reading = ""
    @State private var loading = true
    @State private var sending = false
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Share your readings")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)

                Text("This is exactly what \(specialist.name) will see, word for word. Nothing else from your ledger goes with it.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if loading {
                    Composing(lines: 4)
                        .frame(height: 96)
                        .padding(.top, 28)
                } else if reading.isEmpty {
                    Text("Nothing has been recorded today, so there is nothing to share.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 30)
                } else {
                    Text(reading)
                        .font(Theme.serifBody(16))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.warm, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 24)
                }

                if let failure {
                    Text(failure)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 16)
                }

                Button {
                    Task { await confirm() }
                } label: {
                    ZStack {
                        Text("Send these readings").opacity(sending ? 0 : 1)
                        if sending { ProgressView().tint(Theme.warm) }
                    }
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(reading.isEmpty ? Theme.dust : Theme.ink, in: Capsule())
                }
                .buttonStyle(.press)
                .disabled(reading.isEmpty || sending)
                .padding(.top, 28)
            }
            .padding(.horizontal, 26)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .background(Theme.linen)
        .task { await load() }
    }

    private func load() async {
        snapshot = try? await health.fetchTodaySnapshot()
        reading = Self.compose(snapshot)
        loading = false
    }

    /// The day as a short block of lines, one measure each.
    ///
    /// Plain text rather than anything structured: it travels as a message and
    /// is read by a person, so it has to make sense on its own in a
    /// conversation rather than needing the app to render it.
    static func compose(_ snapshot: HealthSnapshot?) -> String {
        guard let snapshot else { return "" }

        let date = Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
        var lines = ["My readings for \(date):"]

        for group in Metrics.populatedGroups(snapshot) {
            for spec in Metrics.inGroup(group) {
                guard let value = spec.display(snapshot) else { continue }
                let unit = spec.unit.isEmpty ? "" : " \(spec.unit)"
                lines.append("\(spec.label): \(value)\(unit)")
            }
        }

        // The heading alone is not a reading.
        return lines.count > 1 ? lines.joined(separator: "\n") : ""
    }

    private func confirm() async {
        sending = true
        failure = nil
        do {
            try await send(reading)
            Haptics.tap()
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
        sending = false
    }
}
