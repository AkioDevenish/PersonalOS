import SwiftUI
import UIKit

/// How the ledger moves.
///
/// Four springs, the same everywhere, for the same reason there are four
/// colours and two typefaces: motion is part of the vocabulary, and a screen
/// that invents its own timing reads as a different app. Springs rather than
/// curves throughout — a duration ends, a spring settles, and settling is what
/// makes a tap feel like it moved something rather than swapped a picture.
///
/// The overshoot is deliberate but small. This is a page of type on linen; a
/// figure that wobbles twice before landing is a toy. `bouncy` overshoots by a
/// few percent, which reads as life at a glance and disappears under reading.
extension Theme {
    enum Motion {
        /// Selection — a tab, a pill, a marked row. The one spring allowed to
        /// overshoot visibly, because a choice should look like it landed.
        static var bouncy: Animation { honour(.spring(response: 0.36, dampingFraction: 0.62)) }

        /// The extra kick under a tab icon or a glyph, where the thing moving
        /// is small enough that a bigger bounce still reads as precision.
        static var pop: Animation { honour(.spring(response: 0.32, dampingFraction: 0.52)) }

        /// Content arriving or leaving. Barely overshoots: a paragraph that
        /// bounces is unreadable for the half-second it does it.
        static var flow: Animation { honour(.spring(response: 0.42, dampingFraction: 0.86)) }

        /// Under the finger. Fast, so the press is felt rather than watched.
        static var press: Animation { honour(.spring(response: 0.26, dampingFraction: 0.6)) }

        /// A whole screen settling after a push.
        static var settle: Animation { honour(.spring(response: 0.55, dampingFraction: 0.9)) }

        /// Respects the system switch. Reduce Motion doesn't mean no feedback —
        /// it means no travel and no overshoot — so the animations stay, flat
        /// and quick, rather than snapping the interface between states.
        private static func honour(_ animation: Animation) -> Animation {
            UIAccessibility.isReduceMotionEnabled ? .easeOut(duration: 0.18) : animation
        }

        static var reduced: Bool { UIAccessibility.isReduceMotionEnabled }
    }
}

// MARK: - Touch

/// The tap you can feel.
///
/// Light, and only on choices — a selection that changes what's on screen. Not
/// on navigation, where the push is its own confirmation, and never on a
/// repeat of the state you're already in.
enum Haptics {
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Every tappable thing in the app presses in.
///
/// `.plain` was on all of them, which removes the system's blue tint and, with
/// it, any sign that a tap registered — on a design with no fills and no
/// shadows there was nothing left to give feedback. A scale under the finger
/// costs nothing, works on a row of type as well as on a capsule, and springs
/// back with a little overshoot so a released tap feels like it let go.
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

    /// For full-width rows, where 6% of a screen's width is a lurch. The dim
    /// carries most of the feedback here and the scale just backs it up.
    static var pressRow: PressStyle { PressStyle(scale: 0.985, dim: 0.55) }
}

// MARK: - Arrival

/// Content that flows in rather than appearing.
///
/// The metric grid already did this and it's the best moment in the app, so
/// it's a modifier now and the rest of the screens get it too. Pass an index
/// and neighbours arrive on a stagger, which is what makes a list read as
/// assembling itself instead of blinking into place.
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
///
/// A full `.move` transition slides the entire screen past the edge, which on
/// two tabs a thumb-width apart is a bigger journey than the tap deserves. A
/// short drift in the direction of travel says the same thing in 28 points.
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
///
/// Three screens each drew their own and each blinked the ink fill from one
/// capsule to the next. One component now, and the fill is a single shape that
/// slides between them — the selection travels, so you can see where it went.
struct PillPicker<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    var size: CGFloat = 10
    var tracking: CGFloat = 1.5
    var padding: CGFloat = 14
    /// Most of these pickers refetch on change; the animation shouldn't wait
    /// on the network, so the work is handed back through `onSelect` rather
    /// than done inline. Set through the modifier below, not at the call.
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
                        .foregroundStyle(selected ? Theme.warm : Theme.mid)
                        .padding(.horizontal, padding)
                        .padding(.vertical, 8)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Theme.ink)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            } else {
                                Capsule().stroke(Theme.hairline, lineWidth: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.press)
            }
        }
    }
}

/// The ❧ that marks the chosen row in a ruled list.
///
/// Scales in from nothing on the bouncy spring rather than appearing, so the
/// eye follows the choice down the list instead of hunting for it.
struct SelectionMark: View {
    var size: CGFloat = 13

    var body: some View {
        Text("❧")
            .font(Theme.serif(size))
            .foregroundStyle(Theme.amber)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }
}
