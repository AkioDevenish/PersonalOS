import Foundation
import AVFoundation
import Combine
import WebRTC

/// The call itself, run by this app rather than rented from anybody.
///
/// WebRTC connects the two phones directly. What this class does is the work
/// around that: ask the server which relays exist, describe what this device
/// can do, carry those descriptions to the other side through our own
/// signalling, and hand back the two video tracks once they meet.
///
/// The media never touches our servers when a direct path exists, which for
/// two people on ordinary connections is most of the time.
@MainActor
final class CallEngine: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case ringing          // we have offered; nobody has answered yet
        case live
        case failed(String)
        case ended
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var remoteTrack: RTCVideoTrack?
    @Published private(set) var localTrack: RTCVideoTrack?
    @Published private(set) var micOn = true
    @Published private(set) var cameraOn = true
    /// Which way the camera is pointing. Front to begin with, because a
    /// consultation is a conversation before it is anything else.
    @Published private(set) var usingFront = true
    /// Whether a relay is configured. Without one, a fifth of calls cannot
    /// connect and it is better to say so than to let them fail mysteriously.
    @Published private(set) var relayAvailable = true

    private let sessionId: String
    private let client = SessionClient()

    private var peer: RTCPeerConnection?
    private var capturer: RTCCameraVideoCapturer?
    private var audio: RTCAudioTrack?
    private var poller: Task<Void, Never>?
    /// Signals older than this have already been applied.
    private var seen: Double = 0
    /// Candidates that arrived before the remote description did. Applying one
    /// early is an error, and dropping it can lose the only route that works.
    private var early: [RTCIceCandidate] = []
    private var hasRemote = false

    /// One factory for the process. Making several is a documented way to
    /// exhaust the encoder pool.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
    }()

    init(sessionId: String) {
        self.sessionId = sessionId
        super.init()
    }

    // MARK: Starting

    func start() async {
        guard state == .idle else { return }
        state = .connecting

        do {
            let ice = try await client.iceServers(id: sessionId)
            relayAvailable = ice.relayAvailable
            try openPeer(with: ice.servers)
            try await attachCamera()

            // Whoever arrives second answers. Checking for an existing offer
            // rather than assigning roles in advance means either side can
            // dial first, which is what actually happens.
            let waiting = try await client.signals(id: sessionId, after: 0)
            if let offer = waiting.first(where: { $0.kind == "offer" }) {
                try await answer(offer.payload)
            } else {
                try await offer()
            }
            listen()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func openPeer(with servers: [SessionClient.IceServer]) throws {
        let config = RTCConfiguration()
        config.iceServers = servers.map {
            if let username = $0.username, let credential = $0.credential {
                return RTCIceServer(urlStrings: [$0.urls], username: username, credential: credential)
            }
            return RTCIceServer(urlStrings: [$0.urls])
        }
        // Unified Plan is the only semantics current browsers and stacks
        // agree on; Plan B is long deprecated.
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peer = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw CallFailure.noPeerConnection
        }
        self.peer = peer
    }

    private func attachCamera() async throws {
        guard let peer else { return }

        let audioTrack = Self.factory.audioTrack(
            with: Self.factory.audioSource(with: nil), trackId: "audio0"
        )
        peer.add(audioTrack, streamIds: ["stream0"])
        audio = audioTrack

        let source = Self.factory.videoSource()
        let capturer = RTCCameraVideoCapturer(delegate: source)
        self.capturer = capturer

        let track = Self.factory.videoTrack(with: source, trackId: "video0")
        peer.add(track, streamIds: ["stream0"])
        localTrack = track

        try await point(capturer, front: true)
    }

    /// Points the capturer at one camera and starts it.
    ///
    /// 640 by 480 at 30fps: enough for a face on a phone, and cheap enough
    /// that a weak connection is not fighting the encoder as well as the
    /// network.
    private func point(_ capturer: RTCCameraVideoCapturer, front: Bool) async throws {
        let position: AVCaptureDevice.Position = front ? .front : .back
        guard let device = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == position }) else { throw CallFailure.noCamera }

        let format = RTCCameraVideoCapturer.supportedFormats(for: device)
            .min(by: { a, b in
                let aw = CMVideoFormatDescriptionGetDimensions(a.formatDescription).width
                let bw = CMVideoFormatDescriptionGetDimensions(b.formatDescription).width
                return abs(Int(aw) - 640) < abs(Int(bw) - 640)
            })
        guard let format else { throw CallFailure.noCamera }

        try await capturer.startCapture(with: device, format: format, fps: 30)
        usingFront = front
    }

    /// Turns the camera round.
    ///
    /// The capture has to stop before it can start on the other device — the
    /// same session cannot hold two cameras — so there is a visible blink.
    /// That is the hardware, not a bug worth hiding behind a fade.
    func flipCamera() async {
        guard let capturer, state != .ended else { return }
        let wanted = !usingFront
        await withCheckedContinuation { done in
            capturer.stopCapture { done.resume() }
        }
        try? await point(capturer, front: wanted)
    }

    // MARK: The exchange

    private func offer() async throws {
        guard let peer else { return }
        let sdp = try await peer.offer(for: media)
        try await peer.setLocalDescription(sdp)
        try await client.postSignal(id: sessionId, kind: "offer", payload: sdp.sdp)
        state = .ringing
    }

    private func answer(_ remoteSDP: String) async throws {
        guard let peer else { return }
        try await peer.setRemoteDescription(RTCSessionDescription(type: .offer, sdp: remoteSDP))
        hasRemote = true
        try await flushEarly()

        let sdp = try await peer.answer(for: media)
        try await peer.setLocalDescription(sdp)
        try await client.postSignal(id: sessionId, kind: "answer", payload: sdp.sdp)
    }

    private var media: RTCMediaConstraints {
        RTCMediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
            ],
            optionalConstraints: nil
        )
    }

    /// Polls for what the other side has said. A second apart: this is the
    /// handshake, not the media, so a second of latency delays the start of
    /// the call rather than degrading it.
    private func listen() {
        poller?.cancel()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.drain()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func drain() async {
        guard let peer, let signals = try? await client.signals(id: sessionId, after: seen) else { return }

        for signal in signals {
            seen = max(seen, signal.at)
            switch signal.kind {
            case "answer":
                guard !hasRemote else { continue }
                try? await peer.setRemoteDescription(
                    RTCSessionDescription(type: .answer, sdp: signal.payload)
                )
                hasRemote = true
                try? await flushEarly()

            case "offer":
                // Only meaningful if we have not already offered ourselves.
                guard !hasRemote, state == .connecting else { continue }
                try? await answer(signal.payload)

            case "candidate":
                guard let candidate = Self.decode(signal.payload) else { continue }
                if hasRemote {
                    try? await peer.add(candidate)
                } else {
                    // Arrived before the description it belongs to. Held
                    // rather than dropped: it may be the only route that works.
                    early.append(candidate)
                }

            case "bye":
                hangUp(notify: false)

            default:
                continue
            }
        }
    }

    private func flushEarly() async throws {
        guard let peer else { return }
        for candidate in early { try? await peer.add(candidate) }
        early = []
    }

    // MARK: Controls

    func toggleMic() {
        micOn.toggle()
        audio?.isEnabled = micOn
    }

    func toggleCamera() {
        cameraOn.toggle()
        localTrack?.isEnabled = cameraOn
    }

    func hangUp(notify: Bool = true) {
        poller?.cancel()
        capturer?.stopCapture()
        peer?.close()
        peer = nil
        remoteTrack = nil
        localTrack = nil
        state = .ended

        if notify {
            Task {
                try? await client.postSignal(id: sessionId, kind: "bye", payload: "")
                // Cleared so the next attempt is not confused by candidates
                // for addresses that stopped being valid when this ended.
                try? await client.clearSignals(id: sessionId)
            }
        }
    }

    // MARK: Candidates on the wire

    private static func encode(_ candidate: RTCIceCandidate) -> String {
        let payload: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? "",
        ]
        return (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private static func decode(_ payload: String) -> RTCIceCandidate? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sdp = object["candidate"] as? String else { return nil }
        return RTCIceCandidate(
            sdp: sdp,
            sdpMLineIndex: object["sdpMLineIndex"] as? Int32 ?? 0,
            sdpMid: object["sdpMid"] as? String
        )
    }
}

enum CallFailure: LocalizedError {
    case noPeerConnection, noCamera

    var errorDescription: String? {
        switch self {
        case .noPeerConnection: return "The call could not be set up on this phone."
        case .noCamera: return "No front camera is available."
        }
    }
}

extension CallEngine: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { @MainActor in
            try? await client.postSignal(
                id: sessionId, kind: "candidate", payload: Self.encode(candidate)
            )
        }
    }

    nonisolated func peerConnection(_ pc: RTCPeerConnection, didAdd receiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        Task { @MainActor in
            if let track = receiver.track as? RTCVideoTrack { remoteTrack = track }
        }
    }

    nonisolated func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor in
            switch newState {
            case .connected, .completed:
                state = .live
            case .failed:
                // The honest reason, which is nearly always the missing relay.
                state = .failed(
                    relayAvailable
                        ? "The call could not connect."
                        : "The call could not find a direct route, and no relay server is configured."
                )
            case .disconnected:
                if state == .live { state = .connecting }
            case .closed:
                state = .ended
            default:
                break
            }
        }
    }

    nonisolated func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
