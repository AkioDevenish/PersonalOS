import Accelerate
import AVFoundation
import Combine
import Speech
import SwiftUI

/// One thing Pitchfork looked at while working out a reply.
struct ThinkingStep: Identifiable, Equatable, Hashable, Codable {
    var id = UUID()
    let symbol: String
    let label: String
}

/// One line in the conversation.
struct ChatLine: Identifiable, Equatable, Hashable, Codable {
    enum Who: String, Codable { case you, assistant }
    var id = UUID()
    let who: Who
    var text: String
    /// What Pitchfork looked at, and how long it took, for its replies.
    var steps: [ThinkingStep] = []
    var seconds: Int = 0
}

/// The conversation. Replies come from Claude through the Convex backend, which can also look up the
/// person's own synced health history while it answers.
@MainActor
final class Assistant: ObservableObject {
    @Published private(set) var lines: [ChatLine] = []
    @Published private(set) var thinking = false
    /// The steps shown so far while Pitchfork is thinking.
    @Published private(set) var liveSteps: [ThinkingStep] = []
    @Published var failure: String?
    /// Which saved chat this is, so each message updates the same one.
    @Published private(set) var chatID = UUID()

    private var context = ""
    private var sources: [ThinkingStep] = []
    /// A reply can take a few lookups, so this waits longer than the usual call.
    private let transport = Transport(timeout: 90)

    /// Starts a conversation with today's numbers as background: a fresh one, or a saved one picked up again.
    func start(context: String, sources: [ThinkingStep], resuming chat: SavedChat? = nil) {
        lines = chat?.lines ?? []
        chatID = chat?.id ?? UUID()
        failure = nil
        self.context = context
        self.sources = sources
    }

    func send(_ text: String) async -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return nil }

        failure = nil
        let chat = chatID
        lines.append(ChatLine(who: .you, text: text))
        keep()
        thinking = true
        liveSteps = []
        let began = Date()
        let plan = [ThinkingStep(symbol: "text.bubble", label: "Reading your question")]
            + sources
            + [ThinkingStep(symbol: "sparkles", label: "Writing a reply")]
        // Show each step in turn while the reply is on its way.
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
            let answer = try await ask()
            // They moved to another chat while this one was thinking.
            guard chat == chatID else { return nil }
            let clean = MealReading.clean(answer.text.trimmingCharacters(in: .whitespacesAndNewlines))
            let looked = answer.looked.map { ThinkingStep(symbol: "chart.xyaxis.line", label: $0) }
            let steps = Array(plan.dropLast()) + looked + [plan[plan.count - 1]]
            let seconds = max(1, Int(Date().timeIntervalSince(began).rounded()))
            lines.append(ChatLine(who: .assistant, text: clean, steps: steps, seconds: seconds))
            keep()
            return clean
        } catch TransportError.notSignedIn {
            failure = "Sign in to talk to Pitchfork."
        } catch {
            failure = "Pitchfork couldn't answer just now. Check your connection and try again."
        }
        return nil
    }

    private struct Answer: Decodable {
        let text: String
        let looked: [String]
    }

    private func ask() async throws -> Answer {
        let history: [[String: Any]] = lines.map { ["who": $0.who.rawValue, "text": $0.text] }
        let data = try await transport.action(
            "health/pitchfork:reply", ["lines": history, "context": context]
        )
        return try JSONDecoder().decode(Answer.self, from: data)
    }

    private func keep() {
        Chats.shared.save(SavedChat(id: chatID, lines: lines, updated: Date()))
    }
}

/// Reads replies aloud and turns speech into text.
@MainActor
final class Voice: NSObject, ObservableObject {
    @Published private(set) var listening = false
    @Published var heard = ""
    /// How loud each band of the voice is right now, 0 to 1, lowest pitch first. Empty when not listening.
    @Published private(set) var levels: [Float] = []

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
            input.installTap(
                onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0),
                block: Self.tap(request: request, spectrum: Spectrum(bands: 16)) { [weak self] levels in
                    Task { @MainActor [weak self] in if self?.listening == true { self?.levels = levels } }
                }
            )
            engine.prepare()
            try engine.start()

            heard = ""
            listening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let done = error != nil || result?.isFinal == true
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let text { self.heard = text }
                    if done { self.stopListening() }
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
        levels = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor, since the audio engine calls it on its own thread.
    private nonisolated static func tap(
        request: SFSpeechAudioBufferRecognitionRequest,
        spectrum: Spectrum,
        publish: @escaping @Sendable ([Float]) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            publish(spectrum.levels(of: buffer))
        }
    }
}

/// Splits the microphone's sound into bands across the range of a speaking voice.
nonisolated final class Spectrum: @unchecked Sendable {
    let bands: Int
    private let size = 1024
    private let log2n: vDSP_Length = 10
    private let setup: FFTSetup
    private let window: [Float]

    init(bands: Int) {
        self.bands = bands
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// One level per band, 0 to 1, from quiet room to raised voice.
    func levels(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?[0] else { return [] }
        let half = size / 2
        var samples = [Float](repeating: 0, count: size)
        for i in 0..<min(size, Int(buffer.frameLength)) { samples[i] = channel[i] * window[i] }

        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                samples.withUnsafeBytes { raw in
                    vDSP_ctoz(raw.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(half))
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        // Bands spaced evenly in pitch, from a low voice's hum to the hiss of an "s".
        let binWidth = Float(buffer.format.sampleRate) / Float(size)
        let low: Float = 80, high: Float = 6000
        return (0..<bands).map { band in
            let from = low * pow(high / low, Float(band) / Float(bands))
            let to = low * pow(high / low, Float(band + 1) / Float(bands))
            let first = min(half - 1, max(1, Int(from / binWidth)))
            let last = min(half, max(first + 1, Int(to / binWidth)))
            let mean = magnitudes[first..<last].reduce(0, +) / Float(last - first)
            let decibels = 20 * log10(mean / Float(half) + 1e-9)
            return min(1, max(0, (decibels + 70) / 45))
        }
    }
}
