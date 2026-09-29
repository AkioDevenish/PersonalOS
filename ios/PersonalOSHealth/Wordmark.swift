import SwiftUI

/// A spoon: an oval bowl on a tapered handle, drawn pointing up.
struct SpoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let bowl = CGRect(x: rect.minX, y: rect.minY, width: w, height: h * 0.38)
        path.addEllipse(in: bowl)

        let neck = bowl.maxY - h * 0.02
        path.move(to: CGPoint(x: rect.midX - w * 0.09, y: neck))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - w * 0.14, y: rect.maxY - w * 0.14),
            control: CGPoint(x: rect.midX - w * 0.05, y: rect.minY + h * 0.7)
        )
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY - w * 0.14),
            radius: w * 0.14, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + w * 0.09, y: neck),
            control: CGPoint(x: rect.midX + w * 0.05, y: rect.minY + h * 0.7)
        )
        path.closeSubpath()
        return path
    }
}

/// A fork: four tines on a tapered handle, drawn pointing up.
struct ForkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let tineTop = rect.minY
        let tineBottom = rect.minY + h * 0.3
        let headBottom = rect.minY + h * 0.42
        let gap = w * 0.08
        let tine = (w - gap * 3) / 4

        // The tines.
        for i in 0..<4 {
            let x = rect.minX + CGFloat(i) * (tine + gap)
            path.addRoundedRect(
                in: CGRect(x: x, y: tineTop, width: tine, height: tineBottom - tineTop + 2),
                cornerSize: CGSize(width: tine / 2, height: tine / 2)
            )
        }
        // The head, curving into the neck.
        path.move(to: CGPoint(x: rect.minX, y: tineBottom))
        path.addLine(to: CGPoint(x: rect.maxX, y: tineBottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + w * 0.1, y: headBottom + h * 0.06),
            control: CGPoint(x: rect.maxX, y: headBottom)
        )
        // The handle.
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + w * 0.14, y: rect.maxY - w * 0.14),
            control: CGPoint(x: rect.midX + w * 0.06, y: rect.minY + h * 0.72)
        )
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY - w * 0.14),
            radius: w * 0.14, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - w * 0.1, y: headBottom + h * 0.06),
            control: CGPoint(x: rect.midX - w * 0.06, y: rect.minY + h * 0.72)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: tineBottom),
            control: CGPoint(x: rect.minX, y: headBottom)
        )
        path.closeSubpath()
        return path
    }
}

/// How far the fork has twirled, for the wordmark.
private struct Twirl {
    var spin: Double = 0
    var tilt: Double = 14
    var lift: CGFloat = 0
    var width: CGFloat = 1
}

/// "Forklore" in calligraphy, written out as a fork beside it twirls like it's winding pasta, then rests.
struct ForkloreWordmark: View {
    var size: CGFloat = 56
    @State private var written: CGFloat = 0
    @State private var play = false

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.14) {
            fork
            Text("Forklore")
                .font(.custom("SnellRoundhand-Bold", size: size))
                .foregroundStyle(Theme.text)
                .fixedSize()
                .mask(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle().frame(width: geo.size.width * written)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Forklore")
        .onAppear {
            play = true
            withAnimation(.easeInOut(duration: 1.7).delay(0.15)) { written = 1 }
        }
    }

    private var fork: some View {
        ForkShape()
            .fill(Theme.accent.gradient)
            .frame(width: size * 0.3, height: size * 0.95)
            .keyframeAnimator(initialValue: Twirl(), trigger: play) { content, twirl in
                content
                    // Squeezing the width back and forth reads as the fork spinning on its handle.
                    .scaleEffect(x: twirl.width, y: 1)
                    .rotationEffect(.degrees(twirl.tilt), anchor: .bottom)
                    .offset(y: twirl.lift)
            } keyframes: { _ in
                KeyframeTrack(\.width) {
                    CubicKeyframe(0.15, duration: 0.18)
                    CubicKeyframe(1, duration: 0.18)
                    CubicKeyframe(0.15, duration: 0.18)
                    CubicKeyframe(1, duration: 0.18)
                    CubicKeyframe(0.15, duration: 0.18)
                    CubicKeyframe(1, duration: 0.18)
                    CubicKeyframe(0.15, duration: 0.18)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(size * 0.08, duration: 0.3)
                    LinearKeyframe(size * 0.08, duration: 0.9)
                    CubicKeyframe(-size * 0.2, duration: 0.3)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.tilt) {
                    LinearKeyframe(0, duration: 1.2)
                    CubicKeyframe(-24, duration: 0.3)
                    SpringKeyframe(14, duration: 0.5, spring: .bouncy)
                }
            }
    }
}

/// A small spoon that keeps stirring, for while Spoon is thinking.
struct StirringSpoon: View {
    var size: CGFloat = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 2.4
            SpoonShape()
                .fill(Theme.accent.gradient)
                .frame(width: size * 0.3, height: size)
                .rotationEffect(.degrees(15 + sin(t) * 12), anchor: .bottom)
                .offset(x: cos(t) * size * 0.12, y: sin(t) * size * 0.06)
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}
