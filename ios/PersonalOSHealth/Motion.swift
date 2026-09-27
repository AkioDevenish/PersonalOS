import SwiftUI
import UIKit

/// How the ledger moves.
extension Theme {
    enum Motion {
        /// Selection — a tab, a pill, a marked row.
        static var bouncy: Animation { honour(.spring(response: 0.36, dampingFraction: 0.62)) }

        /// The extra kick under a tab icon or a glyph, where the thing moving is small enough that
        /// a bigger bounce still reads as precision.
        static var pop: Animation { honour(.spring(response: 0.32, dampingFraction: 0.52)) }

        /// Content arriving or leaving.
        static var flow: Animation { honour(.spring(response: 0.42, dampingFraction: 0.86)) }

        /// Under the finger.
        static var press: Animation { honour(.spring(response: 0.26, dampingFraction: 0.6)) }

        /// A whole screen settling after a push.
        static var settle: Animation { honour(.spring(response: 0.55, dampingFraction: 0.9)) }

        /// Respects the system switch.
        private static func honour(_ animation: Animation) -> Animation {
            UIAccessibility.isReduceMotionEnabled ? .easeOut(duration: 0.18) : animation
        }

        static var reduced: Bool { UIAccessibility.isReduceMotionEnabled }
    }
}

// MARK: - Touch

/// The tap you can feel.
enum Haptics {
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Every tappable thing in the app presses in.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var dim: Double = 0.7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(Theme.Motion.reduced ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(configuration.isPressed ? dim : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    /// For anything that reads as an object: a capsule, a pill, a tab.
    static var press: PressStyle { PressStyle() }

    /// For full-width rows, where 6% of a screen's width is a lurch.
    static var pressRow: PressStyle { PressStyle(scale: 0.985, dim: 0.55) }
}

// MARK: - Arrival

/// Content that flows in rather than appearing.
struct FlowIn: ViewModifier {
    var index: Int = 0
    var distance: CGFloat = 12

    @State private var arrived = false

    func body(content: Content) -> some View {
        content
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived || Theme.Motion.reduced ? 0 : distance)
            .onAppear {
                guard !arrived else { return }
                withAnimation(Theme.Motion.settle.delay(Double(index) * 0.05)) {
                    arrived = true
                }
            }
    }
}

extension View {
    func flowIn(_ index: Int = 0, distance: CGFloat = 12) -> some View {
        modifier(FlowIn(index: index, distance: distance))
    }
}

/// Sideways drift for content swapping in place — one tab replacing another.
extension AnyTransition {
    static func drift(_ dx: CGFloat) -> AnyTransition {
        .asymmetric(
            insertion: .offset(x: dx).combined(with: .opacity),
            removal: .offset(x: -dx).combined(with: .opacity)
        )
    }
}

// MARK: - Pills

/// The row of capsules that picks a range, a meal or a window.
struct PillPicker<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    var size: CGFloat = 10
    var tracking: CGFloat = 1.5
    var padding: CGFloat = 14
    /// Most of these pickers refetch on change; the animation shouldn't wait on the network, so the
    /// work is handed back through `onSelect` rather than done inline.
    var action: () -> Void = {}
    /// Last, so the label reads as the picker's trailing closure.
    var label: (Value) -> String

    @Namespace private var pill

    func onSelect(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.action = action
        return copy
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { value in
                let selected = value == selection
                Button {
                    guard !selected else { return }
                    Haptics.select()
                    withAnimation(Theme.Motion.bouncy) { selection = value }
                    action()
                } label: {
                    Text(label(value).uppercased())
                        .font(Theme.sans(size, medium: selected))
                        .tracking(tracking)
                        .foregroundStyle(selected ? Theme.surface : Theme.secondaryText)
                        .padding(.horizontal, padding)
                        .padding(.vertical, 8)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Theme.text)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            } else {
                                Capsule().stroke(Theme.separator, lineWidth: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.press)
            }
        }
    }
}

// MARK: - Working

/// The app writing something.
struct Composing: View {
    var lines: Int = 5

    /// Ragged, like a paragraph.
    private let widths: [CGFloat] = [1, 0.96, 0.99, 0.92, 0.58, 0.86, 0.74]
    private let barHeight: CGFloat = 11
    private let gap: CGFloat = 13

    @State private var sweep: CGFloat = -220

    /// Measured once, and the bars laid out from that width.
    var body: some View {
        GeometryReader { geo in
            bars(width: geo.size.width)
                .overlay(alignment: .leading) {
                    if !Theme.Motion.reduced {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Theme.accent.opacity(0.45), location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 190)
                        .offset(x: sweep)
                    }
                }
                // Masked by the same shape it decorates, so the sweep only ever paints on the lines
                // and never on the linen behind them.
                .mask(bars(width: geo.size.width))
                .onAppear {
                    guard !Theme.Motion.reduced else { return }
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        sweep = geo.size.width + 200
                    }
                }
        }
        .frame(height: CGFloat(lines) * barHeight + CGFloat(max(lines - 1, 0)) * gap)
        .accessibilityLabel("Writing your reading")
    }

    private func bars(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<lines, id: \.self) { i in
                Capsule()
                    .fill(Theme.text.opacity(0.09))
                    .frame(width: max(width * widths[i % widths.count], 1), height: barHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Writing

/// One run of type in a generated reading.
struct TypedRun {
    let text: String
    var font: Font = Theme.serifBody(17)
    var color: Color = Theme.text
    var tracking: CGFloat = 0
    var lineSpacing: CGFloat = 6
    var topPadding: CGFloat = 0
    var uppercased: Bool = false

    var rendered: String { uppercased ? text.uppercased() : text }
}

/// A reading, written out rather than posted up.
struct TypedText: View {
    let runs: [TypedRun]
    /// Roughly how long the whole thing should take, whatever its length.
    var duration: Double = 2.6

    @State private var revealed = 0

    private var total: Int { runs.reduce(0) { $0 + $1.text.count } }
    /// Two different readings can run to the same number of characters, so the count is not enough
    /// to know the text has changed.
    private var signature: String { runs.map(\.text).joined(separator: "\u{1}") }
    private var typing: Bool { revealed < total }

    var body: some View {
        Group {
            if washing {
                // Redrawn each frame only while the wash is moving; once the text has landed this
                // collapses to plain, static type.
                TimelineView(.animation) { context in
                    stack.foregroundStyle(wash(at: context.date))
                }
            } else {
                stack
            }
        }
        .task(id: signature) { await write() }
    }

    private var washing: Bool { typing && !Theme.Motion.reduced }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                let start = offset(before: index)
                let visible = min(max(revealed - start, 0), run.text.count)
                if visible > 0 {
                    line(run, visible: visible)
                }
            }
        }
    }

    /// While the wash is running the runs set no colour of their own.
    @ViewBuilder
    private func line(_ run: TypedRun, visible: Int) -> some View {
        let body = Text(String(run.rendered.prefix(visible)))
            .font(run.font)
            .tracking(run.tracking)
            .lineSpacing(run.lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, run.topPadding)

        if washing {
            body
        } else {
            body.foregroundStyle(run.color)
        }
    }

    private func offset(before index: Int) -> Int {
        runs.prefix(index).reduce(0) { $0 + $1.text.count }
    }

    /// Steps in chunks on a 25ms tick rather than one character per frame: sixty state changes a
    /// second through a growing text layout is a lot of work to make a paragraph appear, and at
    /// reading distance the difference is invisible.
    private func write() async {
        revealed = 0
        guard total > 0 else { return }
        guard !Theme.Motion.reduced else { revealed = total; return }

        let tick = 0.025
        let step = max(1, Int(Double(total) * tick / duration))
        while revealed < total {
            try? await Task.sleep(for: .seconds(tick))
            if Task.isCancelled { revealed = total; return }
            revealed = min(total, revealed + step)
        }
    }

    /// Amber through sage and back, travelling slowly across the text.
    private func wash(at date: Date) -> LinearGradient {
        let t = date.timeIntervalSinceReferenceDate
        let shift = CGFloat(sin(t * 0.9)) * 0.45
        return LinearGradient(
            colors: [Theme.accent, Theme.positive, Theme.secondaryText, Theme.accent],
            startPoint: UnitPoint(x: shift - 0.3, y: 0),
            endPoint: UnitPoint(x: shift + 1.3, y: 1)
        )
    }
}

/// Marks the chosen row in a ruled list.
struct SelectionMark: View {
    var size: CGFloat = 13

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(Theme.accent)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }
}
