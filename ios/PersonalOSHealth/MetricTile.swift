import SwiftUI

/// One measurement, written on the ground rather than on a card.
///
/// The glyph does two things. It arrives on a stagger with its neighbours, so
/// the grid assembles rather than appearing all at once — the same idea as the
/// splash, and it makes a dense screen legible for the second it takes to
/// land. Then metrics that describe something continuously happening keep a
/// slow pulse: a heart beats, a flame burns, a drop falls. Metrics that are
/// counts of finished things — steps taken, flights climbed — stay still,
/// because a step count that throbs is decoration rather than information.
struct MetricTile: View {
    let spec: MetricSpec
    let snapshot: HealthSnapshot?
    /// Position in the grid, which sets the entrance delay.
    let index: Int
    let appeared: Bool

    /// Which glyphs earn a continuous animation. Kept deliberately short —
    /// fifteen pulsing icons is a light show, not a dashboard.
    private var isLive: Bool {
        ["resting_hr", "active_energy", "glucose", "sleep"].contains(spec.id)
    }

    private var delay: Double { Double(index) * 0.06 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                glyph
                Kicker(text: spec.label, size: 9)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.flatMap { spec.display($0) } ?? "—")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if !spec.unit.isEmpty {
                    Text(spec.unit)
                        .font(Theme.sans(10))
                        .foregroundStyle(Theme.dust)
                }
            }

            Rule()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: 0.35).delay(delay), value: appeared)
    }

    @ViewBuilder
    private var glyph: some View {
        let base = Image(systemName: spec.symbol)
            .font(.system(size: 12, weight: .light))
            .foregroundStyle(Theme.amber)

        if isLive {
            base
                .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
                .scaleEffect(appeared ? 1 : 0.6)
                .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(delay), value: appeared)
        } else {
            base
                // A single bounce as it lands, then still.
                .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                .scaleEffect(appeared ? 1 : 0.6)
                .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(delay), value: appeared)
        }
    }
}
