import SwiftUI

/// One measurement, written on the ground rather than on a card.
struct MetricTile: View {
    let spec: MetricSpec
    let snapshot: HealthSnapshot?
    /// Position in the grid, which sets the entrance delay.
    let index: Int
    let appeared: Bool

    private var delay: Double { Double(index) * 0.06 }

    /// Far apart, and never the same for two tiles.
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
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                if !spec.unit.isEmpty {
                    Text(spec.unit)
                        .font(Theme.sans(10))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        // The hairline under each figure used to stretch the tile across its grid column; without
        // it the content shrank to its own width and got centred, so a column of figures no longer
        // lined up with anything.
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(Theme.Motion.flow.delay(delay), value: appeared)
    }

    @ViewBuilder
    private var glyph: some View {
        let base = Image(systemName: spec.symbol)
            .font(.system(size: 12, weight: .light))
            .foregroundStyle(Theme.accent)
            .scaleEffect(appeared ? 1 : 0.6)
            .animation(Theme.Motion.pop.delay(delay), value: appeared)

        // Reduce Motion means no idle movement at all.
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
