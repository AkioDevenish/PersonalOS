import PDFKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import Vision

/// Pitchfork, a personal assistant you can type or talk to. It answers out loud unless you tap its blob to mute it.
struct AssistantView: View {
    @EnvironmentObject private var health: HealthKitManager
    @Environment(Store.self) private var store
    @StateObject private var assistant = Assistant()
    @StateObject private var voice = Voice()
    @ObservedObject private var chats = Chats.shared

    @AppStorage("assistant_speaks") private var speaks = true
    @AppStorage(Cuisine.key) private var country = Cuisine.deviceDefault
    @State private var draft = ""
    @State private var locked = false
    @State private var started = false
    @State private var photo: PhotosPickerItem?
    @State private var reading = false
    @State private var pickingPhoto = false
    @State private var pickingFile = false
    @State private var takingPhoto = false
    @State private var micOff = false
    @State private var browsing = false
    @FocusState private var typing: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(assistant.lines) { line in
                        bubble(line).id(line.id)
                    }

                    if assistant.thinking {
                        ThinkingView(steps: assistant.liveSteps)
                            .id("thinking")
                            .transition(.opacity)
                    }

                    if let failure = assistant.failure {
                        Text(failure)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if assistant.lines.isEmpty && !assistant.thinking {
                    welcome.transition(.opacity)
                }
            }
            .onChange(of: assistant.lines.count) { _, _ in
                withAnimation(Theme.Motion.flow) { proxy.scrollTo(assistant.lines.last?.id, anchor: .bottom) }
            }
            .onChange(of: assistant.thinking) { _, now in
                if now { withAnimation(Theme.Motion.flow) { proxy.scrollTo("thinking", anchor: .bottom) } }
            }
            // The keyboard takes the bottom of the screen, so bring the latest message up above it.
            .onChange(of: typing) { _, now in
                guard now, let last = assistant.lines.last?.id else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(Theme.Motion.flow) { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
        // Pinned above the chat, so the buttons stay put while it scrolls under them.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .background { Theme.gradient.ignoresSafeArea(edges: .top) }
        }
        // A solid backdrop, so the chat doesn't show through the message box or behind the keyboard.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
                .background { Theme.gradient.ignoresSafeArea(edges: .bottom) }
        }
        .appBackground()
        .task { await begin() }
        .onChange(of: voice.heard) { _, text in if voice.listening { draft = text } }
        .onChange(of: voice.listening) { was, now in
            // Finished talking: send what was heard.
            if was && !now && !draft.isEmpty { Task { await send(draft) } }
        }
        .onDisappear { voice.stopSpeaking(); voice.stopListening() }
        .sheet(isPresented: $browsing) {
            ChatHistory(chats: chats, current: assistant.chatID) { chat in
                browsing = false
                voice.stopSpeaking()
                Task { await begin(fresh: true, resuming: chat) }
            } onDelete: { chat in
                chats.remove(chat)
                if chat.id == assistant.chatID {
                    voice.stopSpeaking()
                    Task { await begin(fresh: true) }
                }
            }
        }
        .subscriptionNeeded($locked, toDo: "chat with you")
        .alert("Turn on the microphone", isPresented: $micOff) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Pitchfork needs the microphone and speech recognition to hear you.")
        }
    }

    // MARK: Pieces

    /// The menu top left, the chat's name in a pill in the middle, and Pitchfork's blob top right once a
    /// chat is going.
    private var header: some View {
        ZStack {
            HStack {
                MenuButton()
                Spacer()
                if !assistant.lines.isEmpty {
                    blobButton(size: 38)
                        .frame(width: GlassCircle.size, height: GlassCircle.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }

            chatPill
                .padding(.horizontal, GlassCircle.size + 12)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
        .animation(Theme.Motion.flow, value: assistant.lines.isEmpty)
    }

    /// Which chat this is. Tapping it starts a new one or opens the past ones.
    private var chatPill: some View {
        Menu {
            Button("New Chat", systemImage: "square.and.pencil") {
                voice.stopSpeaking()
                Task { await begin(fresh: true) }
            }
            .disabled(assistant.lines.isEmpty)
            Button("Past Chats", systemImage: "clock.arrow.circlepath") { browsing = true }
        } label: {
            HStack(spacing: 6) {
                Text(chatName)
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 18)
            .frame(height: GlassCircle.size)
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel("Chat: \(chatName)")
        .accessibilityHint("Start a new chat or open a past one")
    }

    private var chatName: String {
        assistant.lines.isEmpty
            ? "New Chat"
            : SavedChat(id: assistant.chatID, lines: assistant.lines, updated: .now).title
    }

    /// Before the first message: Pitchfork's blob, a little above the middle.
    private var welcome: some View {
        GeometryReader { geo in
            blobButton(size: min(geo.size.width * 0.42, 170))
                .position(x: geo.size.width / 2, y: geo.size.height * 0.4)
        }
    }

    /// Pitchfork's blob. Tapping it mutes or unmutes the spoken replies.
    private func blobButton(size: CGFloat) -> some View {
        Button {
            speaks.toggle()
            if !speaks { voice.stopSpeaking() }
            Haptics.select()
        } label: {
            PitchforkBlob(size: size, muted: !speaks)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pitchfork")
        .accessibilityValue(speaks ? "Reading replies aloud" : "Muted")
        .accessibilityHint(speaks ? "Double tap to mute" : "Double tap to read replies aloud")
    }

    @ViewBuilder
    private func bubble(_ line: ChatLine) -> some View {
        if line.who == .assistant && !line.steps.isEmpty {
            ThoughtSummary(steps: line.steps, seconds: line.seconds)
        }
        message(line)
    }

    private func message(_ line: ChatLine) -> some View {
        let mine = line.who == .you
        return HStack {
            if mine { Spacer(minLength: 48) }
            Text(line.text)
                .font(Theme.sans(16))
                .foregroundStyle(mine ? Theme.background : Theme.text)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    mine ? Theme.text : Theme.surface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .textSelection(.enabled)
                .contextMenu {
                    if !mine {
                        Button("Read aloud", systemImage: "speaker.wave.2") { voice.speak(line.text) }
                    }
                }
            if !mine { Spacer(minLength: 48) }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// A plus on the left for attachments, then one box: the message, mic and send.
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !voice.listening {
                attach
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            box
        }
        .animation(Theme.Motion.flow, value: voice.listening)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .photosPicker(isPresented: $pickingPhoto, selection: $photo, matching: .images)
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.image, .pdf]) { result in
            if case .success(let url) = result { Task { await readFile(url) } }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in
                takingPhoto = false
                if let image { Task { await readImage(image) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await readPhoto(item) }
        }
    }

    private var box: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if voice.listening {
                VoiceBars(levels: voice.levels)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .padding(.leading, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                TextField("Ask Pitchfork…", text: $draft, axis: .vertical)
                    .font(Theme.sans(16))
                    .lineLimit(1...5)
                    .focused($typing)
                    .padding(.vertical, 9)
                    .submitLabel(.send)
                    .onSubmit { Task { await send(draft) } }
            }

            Button {
                Task { await toggleListening() }
            } label: {
                Image(systemName: voice.listening ? "stop.fill" : "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(voice.listening ? Theme.accent : Theme.secondaryText)
                    .frame(width: 38, height: 38)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.press)
            .accessibilityLabel(voice.listening ? "Stop listening" : "Talk")

            if !voice.listening {
                sendButton
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
    }

    /// The plus: take a photo, pick one from the library, or pick an image or PDF from Files.
    private var attach: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera") { takingPhoto = true }
            }
            Button("Photo Library", systemImage: "photo.on.rectangle") { pickingPhoto = true }
            Button("Files", systemImage: "folder") { pickingFile = true }
        } label: {
            Image(systemName: reading ? "hourglass" : "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: 46, height: 46)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .disabled(reading)
        .accessibilityLabel("Attach a photo or file")
    }

    private var sendButton: some View {
        Button {
                Task { await send(draft) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 34, height: 34)
                    .background(canSend ? Theme.text : Theme.tertiaryText, in: Circle())
            }
            .buttonStyle(.press)
            .disabled(!canSend)
            .padding(.bottom, 2)
            .accessibilityLabel("Send")
    }

    /// Pulls any text out of the photo (a recipe, a label) and adds it to the message.
    private func readPhoto(_ item: PhotosPickerItem) async {
        defer { photo = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await readImage(image)
    }

    /// An image or a PDF picked in Files.
    private func readFile(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        if let pdf = PDFDocument(data: data) {
            reading = true
            defer { reading = false }
            if assistant.failure == Self.noText { assistant.failure = nil }
            add(pdf.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", from: "a file")
        } else if let image = UIImage(data: data) {
            await readImage(image)
        }
    }

    private func readImage(_ image: UIImage) async {
        guard let cgImage = image.cgImage else { return }
        reading = true
        // A new photo replaces the last one's note, but not anything else being shown.
        if assistant.failure == Self.noText { assistant.failure = nil }
        defer { reading = false }
        // Camera photos are stored sideways with the turn in their metadata, which the CGImage drops.
        let orientation = Self.orientation(of: image)
        let text = await Task.detached(priority: .userInitiated) {
            Self.recognizeText(in: cgImage, orientation: orientation)
        }.value
        add(text, from: "a photo")
    }

    private func add(_ text: String, from source: String) {
        guard !text.isEmpty else {
            assistant.failure = Self.noText
            return
        }
        draft = draft.isEmpty ? "From \(source):\n\(text)" : "\(draft)\n\nFrom \(source):\n\(text)"
        typing = true
    }

    private static let noText = "I couldn't find any text in that."

    /// Accurate recognition takes a moment, so it runs off the main thread.
    private nonisolated static func recognizeText(in image: CGImage, orientation: CGImagePropertyOrientation) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !assistant.thinking
    }

    // MARK: Actions

    private func begin(fresh: Bool = false, resuming chat: SavedChat? = nil) async {
        guard fresh || !started else { return }
        started = true
        let (text, sources) = await context()
        assistant.start(context: text, sources: sources, resuming: chat)
    }

    private func send(_ text: String) async {
        // Return on the keyboard skips the disabled send button, and the model takes one question at a time.
        guard !assistant.thinking else { return }
        guard !Paywall.enabled || store.entitlement.isSubscribed else { locked = true; return }
        voice.stopListening()
        draft = ""
        typing = false
        if let reply = await assistant.send(text), speaks { voice.speak(reply) }
    }

    private func toggleListening() async {
        if voice.listening { voice.stopListening(); return }
        guard !Paywall.enabled || store.entitlement.isSubscribed else { locked = true; return }
        if !(await voice.listen()) { micOff = true }
    }

    /// Today's and this week's numbers, for the assistant to draw on.
    private func context() async -> (String, [ThinkingStep]) {
        var parts: [String] = []
        var sources: [ThinkingStep] = []
        if let today = try? await health.fetchTodaySnapshot() {
            let shown = ["steps", "sleep", "active_energy", "resting_hr", "glucose", "carbs"]
                .compactMap { Metrics.by(id: $0) }
                .compactMap { spec -> String? in
                    guard let value = spec.display(today) else { return nil }
                    return "\(spec.label) \(value)\(spec.unit.isEmpty ? "" : " \(spec.unit)")"
                }
            if !shown.isEmpty {
                parts.append("Today: " + shown.joined(separator: ", ") + ".")
                sources.append(ThinkingStep(symbol: "figure.walk", label: "Checked today's numbers"))
            }
        }
        if let week = try? await health.fetchHistoricalSnapshots(days: 7) {
            let nights = week.compactMap { snap in Metrics.by(id: "sleep").flatMap { $0.display(snap) } }
            if !nights.isEmpty {
                parts.append("Sleep over the last week (hours): " + nights.joined(separator: ", ") + ".")
                sources.append(ThinkingStep(symbol: "moon.stars", label: "Looked at your sleep this week"))
            }
        }
        if !country.isEmpty {
            parts.append("They cook and shop in \(Cuisine.name(for: country)).")
            sources.append(ThinkingStep(symbol: "fork.knife", label: "Thought about food in \(Cuisine.name(for: country))"))
        }
        return (parts.isEmpty ? "No health numbers recorded today." : parts.joined(separator: "\n"), sources)
    }
}

/// A fork twirling, then each step appearing on a timeline.
private struct ThinkingView: View {
    let steps: [ThinkingStep]
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                TwirlingFork(size: 20)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: Circle())
                Text("Pitchfork is thinking…")
                    .font(Theme.sans(15, medium: true))
                    .foregroundStyle(Theme.secondaryText)
                    .opacity(shimmer ? 0.45 : 1)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            }
            StepList(steps: steps)
        }
        .onAppear { shimmer = true }
    }
}

/// The steps, joined by a thin line like a timeline.
private struct StepList: View {
    let steps: [ThinkingStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps) { step in
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Rectangle().fill(Theme.separator).frame(width: 1.5, height: 10)
                        Image(systemName: step.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Theme.surface, in: Circle())
                    }
                    Text(step.label)
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.text)
                        .padding(.top, 10)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.top, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// "Thought for 3s", which opens to show the steps.
private struct ThoughtSummary: View {
    let steps: [ThinkingStep]
    let seconds: Int
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.select()
                withAnimation(Theme.Motion.flow) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    ForkShape()
                        .fill(Theme.accent.gradient)
                        .frame(width: 7, height: 16)
                        .rotationEffect(.degrees(20))
                    Text("Thought for \(seconds)s")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryText)
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .buttonStyle(.plain)
            if open { StepList(steps: steps) }
        }
    }
}

/// Pitchfork's face: a soft, slowly shifting blob of warm colour. Muted, it fades to grey.
private struct PitchforkBlob: View {
    let size: CGFloat
    var muted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors = [
        Color(red: 0.84, green: 0.66, blue: 0.47),
        Color(red: 0.72, green: 0.49, blue: 0.36),
        Color(red: 0.91, green: 0.80, blue: 0.64),
        Color(red: 0.62, green: 0.45, blue: 0.33),
        Color(red: 0.84, green: 0.66, blue: 0.47),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // The canvas runs past the blob on every side so the glow fades out before its edge,
            // rather than being cut off in a square.
            Canvas { context, canvas in
                let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let radius = size * 0.4
                let shape = blob(center: center, radius: radius, t: t)
                let colours = Gradient(colors: colors)

                // A soft glow behind it.
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: size * 0.12))
                    glow.opacity = 0.45
                    glow.fill(shape, with: .conicGradient(colours, center: center, angle: .radians(t * 0.35)))
                }
                context.fill(shape, with: .conicGradient(colours, center: center, angle: .radians(t * 0.35)))
                // A highlight, top left, so it reads as round.
                context.fill(shape, with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.45), .white.opacity(0)]),
                    center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.4),
                    startRadius: 0,
                    endRadius: radius * 1.1
                ))
            }
            .frame(width: size * 1.6, height: size * 1.6)
            .saturation(muted ? 0.1 : 1)
            .opacity(muted ? 0.6 : 1)
            .padding(-size * 0.3)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if muted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: max(9, size * 0.14)))
                    .foregroundStyle(Theme.tertiaryText)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }
        }
        .contentShape(Circle())
        .animation(Theme.Motion.flow, value: muted)
        .accessibilityHidden(true)
    }

    /// A circle whose edge ripples a little, a few slow waves at once.
    private func blob(center: CGPoint, radius: CGFloat, t: Double) -> Path {
        Path { path in
            let points = 96
            for i in 0...points {
                let angle = Double(i) / Double(points) * 2 * .pi
                let wobble = 0.045 * sin(3 * angle + t * 0.9)
                    + 0.035 * sin(5 * angle - t * 1.3)
                    + 0.025 * sin(2 * angle + t * 0.6)
                let r = radius * (1 + wobble)
                let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }
}

/// While listening: bars that rise and fall with your voice, low pitches in the middle.
private struct VoiceBars: View {
    let levels: [Float]
    private let bands = 16

    var body: some View {
        // Mirrored, so the bars spread out from the middle.
        let half = (0..<bands).map { $0 < levels.count ? CGFloat(levels[$0]) : 0 }
        let bars = half.reversed() + half
        HStack(alignment: .center, spacing: 3) {
            ForEach(bars.indices, id: \.self) { i in
                Capsule()
                    .fill(Theme.accent.gradient)
                    .frame(width: 3, height: 4 + bars[i] * 26)
                    .opacity(0.45 + bars[i] * 0.55)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: levels)
        .accessibilityLabel("Listening")
    }
}

/// The camera, for photographing a recipe or a label.
private struct CameraPicker: UIViewControllerRepresentable {
    /// The photo, or nil if they cancelled. Either way the camera should close.
    let done: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.done(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.done(nil)
        }
    }
}

/// Past chats, newest first. Tap one to carry on where it left off, or swipe to delete it.
private struct ChatHistory: View {
    @ObservedObject var chats: Chats
    let current: UUID
    let onPick: (SavedChat) -> Void
    let onDelete: (SavedChat) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if chats.all.isEmpty {
                    Text("Your chats with Pitchfork will show up here.")
                        .font(Theme.sans(15))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(chats.all) { chat in
                            Button { onPick(chat) } label: { row(chat) }
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            offsets.map { chats.all[$0] }.forEach(onDelete)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .appBackground()
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ chat: SavedChat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(chat.title)
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(chat.updated.formatted(.relative(presentation: .named)))
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer()
            if chat.id == current {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
