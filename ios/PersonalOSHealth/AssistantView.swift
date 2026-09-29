import SwiftUI

/// A personal assistant you can type or talk to. It answers out loud if you want it to.
struct AssistantView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var session: Session
    @Environment(Store.self) private var store
    @StateObject private var assistant = Assistant()
    @StateObject private var voice = Voice()

    @AppStorage("assistant_speaks") private var speaks = true
    @AppStorage(Cuisine.key) private var country = Cuisine.deviceDefault
    @State private var draft = ""
    @State private var locked = false
    @State private var started = false
    @FocusState private var typing: Bool

    private let starters = [
        "What should I eat tonight?",
        "How did I sleep this week?",
        "Give me a quick lunch idea",
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if assistant.lines.isEmpty {
                        welcome
                    }

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
            .onChange(of: assistant.lines.count) { _, _ in
                withAnimation(Theme.Motion.flow) { proxy.scrollTo(assistant.lines.last?.id, anchor: .bottom) }
            }
            .onChange(of: assistant.thinking) { _, now in
                if now { withAnimation(Theme.Motion.flow) { proxy.scrollTo("thinking", anchor: .bottom) } }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .appBackground()
        .task { await begin() }
        .onChange(of: voice.heard) { _, text in if voice.listening { draft = text } }
        .onChange(of: voice.listening) { was, now in
            // Finished talking: send what was heard.
            if was && !now && !draft.isEmpty { Task { await send(draft) } }
        }
        .onDisappear { voice.stopSpeaking(); voice.stopListening() }
        .subscriptionNeeded($locked, toDo: "chat with you")
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Spoon")
                .font(Theme.serif(28))
                .foregroundStyle(Theme.text)
            Spacer()
            Button {
                speaks.toggle()
                if !speaks { voice.stopSpeaking() }
                Haptics.select()
            } label: {
                Image(systemName: speaks ? "speaker.wave.2.fill" : "speaker.slash")
                    .font(.system(size: 17))
                    .foregroundStyle(speaks ? Theme.accent : Theme.tertiaryText)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.press)
            .accessibilityLabel(speaks ? "Stop reading replies aloud" : "Read replies aloud")

            if !assistant.lines.isEmpty {
                Button {
                    voice.stopSpeaking()
                    Task { await begin(fresh: true) }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.text)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.press)
                .accessibilityLabel("New conversation")
            }
        }
        .padding(.top, 12)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(greeting)
                .font(Theme.serif(24))
                .foregroundStyle(Theme.text)
            Text("Ask me about food, cooking, or your health numbers. You can type or tap the mic.")
                .font(Theme.sans(15))
                .foregroundStyle(Theme.secondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(starters, id: \.self) { starter in
                    Button { Task { await send(starter) } } label: {
                        Text(starter)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Theme.surface.opacity(0.8), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
                    }
                    .buttonStyle(.press)
                }
            }
            .padding(.top, 6)
        }
        .padding(.top, 24)
    }

    private var greeting: String {
        let name = session.account?.name?.split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? "Hi, I'm Spoon. What can I help with?" : "Hi \(name), I'm Spoon. What can I help with?"
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

    private var composer: some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleListening() }
            } label: {
                Image(systemName: voice.listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(voice.listening ? Theme.background : Theme.text)
                    .frame(width: 44, height: 44)
                    .background(voice.listening ? Theme.accent : Theme.surface, in: Circle())
            }
            .buttonStyle(.press)
            .accessibilityLabel(voice.listening ? "Stop listening" : "Talk")

            TextField(voice.listening ? "Listening…" : "Message", text: $draft, axis: .vertical)
                .font(Theme.sans(16))
                .lineLimit(1...5)
                .focused($typing)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .submitLabel(.send)
                .onSubmit { Task { await send(draft) } }

            Button {
                Task { await send(draft) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 44, height: 44)
                    .background(canSend ? Theme.text : Theme.tertiaryText, in: Circle())
            }
            .buttonStyle(.press)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !assistant.thinking
    }

    // MARK: Actions

    private func begin(fresh: Bool = false) async {
        guard fresh || !started else { return }
        started = true
        let (text, sources) = await context()
        assistant.start(context: text, sources: sources)
    }

    private func send(_ text: String) async {
        guard !Paywall.enabled || store.entitlement.isSubscribed else { locked = true; return }
        voice.stopListening()
        draft = ""
        typing = false
        if let reply = await assistant.send(text), speaks { voice.speak(reply) }
    }

    private func toggleListening() async {
        if voice.listening { voice.stopListening(); return }
        guard !Paywall.enabled || store.entitlement.isSubscribed else { locked = true; return }
        if !(await voice.listen()) {
            assistant.failure = "Allow the microphone and speech recognition in Settings to talk to me."
        }
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

/// A spoon stirring, then each step appearing on a timeline.
private struct ThinkingView: View {
    let steps: [ThinkingStep]
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                StirringSpoon(size: 22)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: Circle())
                Text("Spoon is thinking…")
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
                    SpoonShape()
                        .fill(Theme.accent.gradient)
                        .frame(width: 6, height: 16)
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
