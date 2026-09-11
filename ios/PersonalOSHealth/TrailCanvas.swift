import SwiftUI
import CoreLocation

/// The trail drawn into empty space, with no map underneath it.
///
/// MapKit will always put real streets and their names below whatever is drawn
/// on top, and there is no supported way to take the labels away. Tesla's
/// screen has none of that: it is a world built only from what the car can
/// see. This is the same idea — the only things on screen are the ground, a
/// grid for scale, and where somebody actually walked.
///
/// The projection is a genuine one rather than a squashed overhead view. Every
/// point sits on a flat plane, the camera hovers above and behind it looking
/// forward, and each point is divided by its distance from that camera. That
/// single divide is what makes far things converge, and it is the whole reason
/// the picture reads as a world rather than a chart.
struct TrailCanvas: View {
    let outings: [[Trail.Point]]
    /// Where the eye sits. Nil until there is something to look at.
    let focus: Trail.Point?
    /// Which way is "away". Radians, clockwise from north.
    let heading: Double

    /// How far back the camera sits from the focus, in metres. Pinching moves
    /// it, which is what zoom means on a ground plane.
    @State private var back: Double = 140
    @State private var pinchStart: Double?
    @State private var turn: Double = 0
    @State private var turnStart: Double?

    /// Height of the camera above the ground, in metres.
    private let height: Double = 55
    /// Focal length in points. Larger is a longer lens and a flatter world.
    private let focal: Double = 620
    /// Nothing closer than this is drawn, or it stretches to infinity.
    private let near: Double = 8

    private static let ground = Color(red: 0.07, green: 0.07, blue: 0.08)
    private static let core = Color(red: 0.82, green: 0.90, blue: 1.0)
    private static let glow = Color(red: 0.44, green: 0.68, blue: 1.0)
    private static let grid = Color(red: 0.42, green: 0.52, blue: 0.66)
    /// A band where the ground meets nothing, so the plane has an edge.
    private static let sky = Color(red: 0.13, green: 0.16, blue: 0.22)

    var body: some View {
        Canvas { context, size in
            let horizon = size.height * 0.30
            draw(grid: context, size: size, horizon: horizon)
            draw(trail: context, size: size, horizon: horizon)
            draw(ego: context, size: size)
        }
        .background(Self.ground)
        .gesture(
            SimultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = pinchStart ?? back
                        pinchStart = start
                        // Pinching out brings the camera closer.
                        back = min(4000, max(40, start / value.magnification))
                    }
                    .onEnded { _ in pinchStart = nil },
                DragGesture()
                    .onChanged { value in
                        let start = turnStart ?? turn
                        turnStart = start
                        turn = start + value.translation.width / 160
                    }
                    .onEnded { _ in turnStart = nil }
            )
        )
    }

    // MARK: Projection

    /// Metres east and north of the focus point.
    private func plane(_ point: Trail.Point) -> (x: Double, z: Double) {
        guard let focus else { return (0, 0) }
        let latitude = focus.lat * .pi / 180
        return (
            x: (point.lon - focus.lon) * 111_320 * cos(latitude),
            z: (point.lat - focus.lat) * 110_540
        )
    }

    /// One ground point, onto the screen. Nil when it is behind the camera.
    private func project(_ point: Trail.Point, _ size: CGSize, _ horizon: CGFloat) -> CGPoint? {
        let flat = plane(point)
        let angle = -heading + turn

        // Rotate so the direction of travel runs away from the viewer.
        let x = flat.x * cos(angle) - flat.z * sin(angle)
        let z = flat.x * sin(angle) + flat.z * cos(angle)

        // The camera sits `back` metres behind the focus, so everything at the
        // focus is that far in front of it.
        let depth = z + back
        guard depth > near else { return nil }

        return CGPoint(
            x: size.width / 2 + focal * x / depth,
            y: horizon + focal * height / depth
        )
    }

    // MARK: Drawing

    /// A grid on the ground, which is what gives the projection something to
    /// be seen against. Without it the trail floats and the tilt is invisible.
    private func draw(grid context: GraphicsContext, size: CGSize, horizon: CGFloat) {
        // The ground fades up into nothing rather than stopping at a hard
        // line, which is what stops the far distance reading as a wall.
        context.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: horizon + 40)),
            with: .linearGradient(
                Gradient(colors: [Self.sky, Self.ground]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: horizon + 40)
            )
        )

        // Spacing widens as the camera pulls back, so the grid never becomes
        // a solid wash at distance.
        let step = max(25.0, (back / 6).rounded() * 10)
        let reach = back * 6

        var line = -reach
        while line <= reach {
            // Each rail drawn on its own so it can fade with distance. One
            // flat stroke for the whole grid was the bug: at a low enough
            // opacity to survive the near lines, the far ones vanished — and
            // the opacity that was there made every line invisible against
            // the ground.
            for rail in [Rail.depth, Rail.across] {
                var path = Path()
                appendRail(&path, along: rail, at: line, step: step, reach: reach,
                           size: size, horizon: horizon)

                // How far away this line is, as a fraction of what is drawn.
                let distance = rail == .depth
                    ? abs(line) / reach                 // sideways: fades at the edges
                    : max(0, (line + back) / (reach + back))  // ahead: fades into the horizon
                let strength = max(0.06, 0.5 * (1 - distance))

                context.stroke(path, with: .color(Self.grid.opacity(strength)), lineWidth: 1)
            }
            line += step
        }
    }

    private enum Rail { case depth, across }

    private func appendRail(
        _ path: inout Path,
        along rail: Rail,
        at offset: Double,
        step: Double,
        reach: Double,
        size: CGSize,
        horizon: CGFloat
    ) {
        var started = false
        var run = -reach
        while run <= reach {
            let x = rail == .depth ? offset : run
            let z = rail == .depth ? run : offset

            let depth = z + back
            if depth > near {
                let point = CGPoint(
                    x: size.width / 2 + focal * x / depth,
                    y: horizon + focal * height / depth
                )
                if started { path.addLine(to: point) } else { path.move(to: point); started = true }
            } else {
                started = false
            }
            run += step
        }
    }

    private func draw(trail context: GraphicsContext, size: CGSize, horizon: CGFloat) {
        for outing in outings {
            var path = Path()
            var started = false

            for point in outing {
                guard let screen = project(point, size, horizon) else {
                    // Behind the camera: break the stroke rather than drawing
                    // a line across the screen to where it reappears.
                    started = false
                    continue
                }
                if started { path.addLine(to: screen) } else { path.move(to: screen); started = true }
            }

            // Three passes: halo, band, core. A single line has no glow.
            context.stroke(path, with: .color(Self.glow.opacity(0.14)),
                           style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Self.glow.opacity(0.34)),
                           style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Self.core),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    /// Where you are: a chevron at the focus, pointing the way you were going.
    private func draw(ego context: GraphicsContext, size: CGSize) {
        guard focus != nil else { return }
        let base = CGPoint(x: size.width / 2, y: size.height * 0.30 + focal * height / back)
        guard base.y.isFinite, base.y < size.height else { return }

        var mark = Path()
        mark.move(to: CGPoint(x: base.x, y: base.y - 13))
        mark.addLine(to: CGPoint(x: base.x - 9, y: base.y + 9))
        mark.addLine(to: CGPoint(x: base.x, y: base.y + 3))
        mark.addLine(to: CGPoint(x: base.x + 9, y: base.y + 9))
        mark.closeSubpath()

        context.fill(mark, with: .color(Self.core))
        context.stroke(mark, with: .color(Self.glow.opacity(0.6)), lineWidth: 6)
    }
}
