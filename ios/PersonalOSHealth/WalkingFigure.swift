import SwiftUI

/// The walking figure, walking.
///
/// There is one engraving and it is a single moment of a stride, so there
/// are no other leg positions to move between. What reads as walking is what
/// the body does around the legs: it rises and falls twice each stride, once
/// per foot, and rocks slightly forward and back. The ground passes under him
/// at the speed he would cover it, which is what turns a figure bobbing in
/// place into one going somewhere.
///
/// A real walk cycle would need a set of drawn frames of the same figure.
/// Until those exist, this is the honest version of him moving.
///
/// Still under Reduce Motion: a figure pacing on a loop is exactly the kind
/// of idle movement that setting asks apps not to make.
struct WalkingFigure: View {
    /// Seconds for a full stride, two steps. About a relaxed walking pace.
    private let stride: Double = 1.15
    /// How far the ground moves in one stride, in points.
    private let reach: Double = 70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let phase = (t / stride).truncatingRemainder(dividingBy: 1) * 2 * .pi

            VStack(spacing: 0) {
                Image("stride")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.text)
                    // Highest as each leg passes under the body, twice a
                    // stride; lowest with both feet planted.
                    .offset(y: -abs(sin(phase)) * 4)
                    .rotationEffect(.degrees(sin(phase) * 1.1), anchor: .bottom)

                ground(t)
                    .frame(height: 10)
                    .padding(.top, -8)
            }
        }
        .accessibilityHidden(true)
    }

    /// Dotted ground passing leftward, so he walks right, the way he faces.
    private func ground(_ t: Double) -> some View {
        Canvas { context, size in
            let spacing: CGFloat = 9
            let travel = CGFloat((t / stride) * reach).truncatingRemainder(dividingBy: spacing)
            var x = -travel
            while x < size.width {
                // Faded at both ends, so the ground is a stretch he is on
                // rather than a line that stops.
                let edge = min(x, size.width - x) / (size.width * 0.3)
                let alpha = max(0, min(1, edge)) * 0.45
                let dot = Path(ellipseIn: CGRect(x: x, y: size.height / 2 - 1, width: 2, height: 2))
                context.fill(dot, with: .color(Theme.text.opacity(alpha)))
                x += spacing
            }
        }
    }
}
