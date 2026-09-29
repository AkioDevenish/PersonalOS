import AVFoundation
import Combine
import FoundationModels
import Speech
import SwiftUI

/// One thing Spoon looked at while working out a reply.
struct ThinkingStep: Identifiable, Equatable, Hashable {
    let id = UUID()
    let symbol: String
    let label: String
}

/// One line in the conversation.
struct ChatLine: Identifiable, Equatable {
    enum Who { case you, assistant }
    let id = UUID()
    let who: Who
    var text: String
    /// What Spoon looked at, and how long it took, for its replies.
    var steps: [ThinkingStep] = []
    var seconds: Int = 0
}

/// The conversation, run on the phone's own model so your data stays on the phone.
@MainActor
final class Assistant: ObservableObject {
    @Published private(set) var lines: [ChatLine] = []
    @Published private(set) var thinking = false
    /// The steps shown so far while Spoon is thinking.
    @Published private(set) var liveSteps: [ThinkingStep] = []
    @Published var failure: String?

    private var session: LanguageModelSession?
    private var sources: [ThinkingStep] = []

    /// Starts a fresh conversation with today's numbers as background.
    func start(context: String, sources: [ThinkingStep]) {
        lines = []
        self.sources = sources
        session = LanguageModelSession(instructions: Self.instructions(context: context))
    }

    func send(_ text: String) async -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session else { return nil }
        guard OnDeviceInsights.availability.isReady else {
            failure = OnDeviceInsights.availability.explanation
            return nil
        }

        failure = nil
        lines.append(ChatLine(who: .you, text: text))
        thinking = true
        liveSteps = []
        let began = Date()
        let plan = [ThinkingStep(symbol: "text.bubble", label: "Reading your question")]
            + sources
            + [ThinkingStep(symbol: "sparkles", label: "Writing a reply")]
        // Show each step in turn while the model works.
        let reveal = Task { @MainActor in
            for step in plan {
                withAnimation(Theme.Motion.flow) { liveSteps.append(step) }
                try? await Task.sleep(for: .milliseconds(650))
            }
        }
        defer {
            reveal.cancel()
            thinking = false
            liveSteps = []
        }

        do {
            let reply = try await session.respond(to: text).content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let clean = MealReading.clean(reply)
            let seconds = max(1, Int(Date().timeIntervalSince(began).rounded()))
            lines.append(ChatLine(who: .assistant, text: clean, steps: plan, seconds: seconds))
            return clean
        } catch let error as LanguageModelSession.GenerationError {
            failure = OnDeviceInsights.OnDeviceError.generation(error).localizedDescription
        } catch {
            failure = error.localizedDescription
        }
        return nil
    }

    private static func instructions(context: String) -> String {
        """
        Your name is Spoon. You are a friendly personal assistant inside a food and health app \
        called Spoonful. Talk like a helpful \
        friend: short, warm, plain sentences. No lists unless asked. No long dashes.

        You help with what to eat, cooking, groceries, and making sense of the person's own \
        health numbers below. Never diagnose anything or mention medication. If something sounds \
        medical or worrying, suggest they talk to a nutritionist in the app or see a doctor.

        What you know about them today:
        \(context)
        """
    }
}

/// Reads replies aloud and turns speech into text.
@MainActor
final class Voice: NSObject, ObservableObject {
    @Published private(set) var listening = false
    @Published var heard = ""

    private let synthesizer = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Starts listening. Returns false if permission was refused or speech isn't available.
    func listen() async -> Bool {
        stopSpeaking()
        let allowed = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard allowed, await AVAudioApplication.requestRecordPermission(),
              let recognizer, recognizer.isAvailable else { return false }

        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audio.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            self.request = request

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()

            heard = ""
            listening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result { self.heard = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self.stopListening() }
                }
            }
            return true
        } catch {
            stopListening()
            return false
        }
    }

    func stopListening() {
        guard listening || engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
