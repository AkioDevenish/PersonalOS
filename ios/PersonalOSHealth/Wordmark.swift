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

/// Where the spoon is during its little routine.
private struct SpoonPose {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 18
    var opacity: Double = 1
}

/// "Spoonful" in calligraphy, written out as a spoon stirs beside it and then scoops.
struct SpoonfulWordmark: View {
    var size: CGFloat = 56
    @State private var written: CGFloat = 0
    @State private var play = false

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.12) {
            spoon
            Text("Spoonful")
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
        .accessibilityLabel("Spoonful")
        .onAppear {
            play = true
            withAnimation(.easeInOut(duration: 1.7).delay(0.15)) { written = 1 }
        }
    }

    private var spoon: some View {
        let r = size * 0.1
        return SpoonShape()
            .fill(Theme.accent.gradient)
            .frame(width: size * 0.28, height: size * 0.95)
            .keyframeAnimator(initialValue: SpoonPose(), trigger: play) { content, pose in
                content
                    .rotationEffect(.degrees(pose.angle), anchor: .bottom)
                    .offset(x: pose.x, y: pose.y)
                    .opacity(pose.opacity)
            } keyframes: { _ in
                // Two stirs round the pot, then a scoop up, then it rests.
                KeyframeTrack(\.x) {
                    CubicKeyframe(r, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(-r, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(r, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(-r, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    SpringKeyframe(0, duration: 0.6)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(-r * 0.5, duration: 0.2)
                    CubicKeyframe(-r, duration: 0.2)
                    CubicKeyframe(-r * 0.5, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(-r * 0.5, duration: 0.2)
                    CubicKeyframe(-r, duration: 0.2)
                    CubicKeyframe(-r * 0.5, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(-size * 0.22, duration: 0.3)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.angle) {
                    LinearKeyframe(18, duration: 1.6)
                    CubicKeyframe(-30, duration: 0.3)
                    SpringKeyframe(12, duration: 0.5, spring: .bouncy)
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
