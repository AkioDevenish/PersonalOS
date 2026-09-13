import SwiftUI

/// One measurement, written on the ground rather than on a card.
///
/// The glyph does two things. It arrives on a stagger with its neighbours, so
/// the grid assembles rather than appearing all at once — the same idea as the
/// splash, and it makes a dense screen legible for the second it takes to land.
/// Then it keeps moving the way its own measurement moves: a heart beats, a
/// flame breathes, a sun turns, footprints wiggle.
///
/// Only four of them used to move at all, on the reasoning that a step count
/// which throbs is decoration rather than information. The worry behind that
/// was right — nineteen icons pulsing in unison is a light show — but holding
/// most of them still was the wrong fix. What keeps this quiet is timing, not
/// stillness: the continuous effects belong to the handful of things that
/// genuinely never stop, everything else moves on a long period, and each
/// tile's period is offset by its position so no two glyphs ever move together.
struct MetricTile: View {
    let spec: MetricSpec
    let snapshot: HealthSnapshot?
    /// Position in the grid, which sets the entrance delay.
    let index: Int
    let appeared: Bool

    private var delay: Double { Double(index) * 0.06 }

    /// Far apart, and never the same for two tiles. Movement you notice on
    /// glance and stop seeing while you read.
    private var period: Double { 3.5 + Double(index % 7) * 0.9 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                glyph
                Kicker(text: spec.label, size: 9)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.flatMap { spec.display($0) } ?? "·")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if !spec.unit.isEmpty {
                    Text(spec.unit)
                        .font(Theme.sans(10))
                        .foregroundStyle(Theme.dust)
                }
            }
        }
        // The hairline under each figure used to stretch the tile across its
        // grid column; without it the content shrank to its own width and got
        // centred, so a column of figures no longer lined up with anything.
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(Theme.Motion.flow.delay(delay), value: appeared)
    }

    @ViewBuilder
    private var glyph: some View {
        let base = Image(systemName: spec.symbol)
            .font(.system(size: 12, weight: .light))
            .foregroundStyle(Theme.amber)
            .scaleEffect(appeared ? 1 : 0.6)
            .animation(Theme.Motion.pop.delay(delay), value: appeared)

        // Reduce Motion means no idle movement at all. A glyph that never
        // stops is exactly what that setting exists to turn off, so the
        // entrance stays and the loop doesn't start.
        if Theme.Motion.reduced {
            base
        } else {
            switch spec.motion {
            case .beat:
                base.symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
            case .breathing:
                base.symbolEffect(.breathe, options: .repeat(.continuous))
            case .periodicWiggle:
                base.symbolEffect(.wiggle, options: .repeat(.periodic(delay: period)))
            case .periodicRotate:
                base.symbolEffect(.rotate, options: .repeat(.periodic(delay: period)))
            case .periodicBounce:
                base.symbolEffect(.bounce, options: .repeat(.periodic(delay: period)))
            }
        }
    }
}
