import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

/// The walking figure, walking.
struct WalkingVideo: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Image("stride")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.text)
        } else {
            LoopingPlayer(inverted: scheme == .dark)
                // Rebuilt when the appearance changes, so the inversion is decided once per player
                // rather than checked every frame.
                .id(scheme)
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

private struct LoopingPlayer: UIViewRepresentable {
    let inverted: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        guard let url = Bundle.main.url(forResource: "walking", withExtension: "mp4") else { return view }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let invert = inverted
        item.videoComposition = AVVideoComposition(asset: asset) { request in
            request.finish(with: Self.clean(request.sourceImage, invert: invert), context: nil)
        }

        let player = AVQueuePlayer()
        player.isMuted = true
        // It is decoration; the screen should still be allowed to sleep.
        player.preventsDisplaySleepDuringVideoPlayback = false
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        player.play()
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    /// Colour out, near-white to white, then inverted for a dark page.
    static func clean(_ image: CIImage, invert: Bool) -> CIImage {
        let mono = CIFilter.colorControls()
        mono.inputImage = image.clampedToExtent()
        mono.saturation = 0

        let curve = CIFilter.toneCurve()
        curve.inputImage = mono.outputImage
        curve.point0 = CGPoint(x: 0, y: 0)
        curve.point1 = CGPoint(x: 0.35, y: 0.3)
        curve.point2 = CGPoint(x: 0.65, y: 0.68)
        curve.point3 = CGPoint(x: 0.86, y: 1)
        curve.point4 = CGPoint(x: 1, y: 1)

        var out = curve.outputImage ?? image
        if invert {
            let flip = CIFilter.colorInvert()
            flip.inputImage = out
            out = flip.outputImage ?? out
        }
        return out.cropped(to: image.extent)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: Coordinator) {
        view.playerLayer.player?.pause()
        coordinator.looper = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
