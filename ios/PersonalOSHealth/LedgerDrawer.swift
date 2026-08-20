import SwiftUI

/// The index of the ledger, kept off to the side.
///
/// Built against my own advice, so it is worth writing down what the risk is:
/// a drawer hides its contents behind a gesture, and the things in this one are
/// three of the app's four verbs rather than occasional settings. If people
/// stop opening Records, this is why.
///
/// What that argues for, given the decision, is a drawer that is as hard to
/// miss as a drawer can be. So it has a visible handle on the edge rather than
/// only a swipe, the handle is amber where nothing else on the ground is, and
/// the panel pushes the page aside instead of covering it, so what happened is
/// legible in one glance.
struct LedgerDrawer: View {
    let open: Bool
    let go: (Route) -> Void

    /// How far the page moves over. Wide enough for a serif line, short enough
    /// that the page behind is still recognisably there.
    static let width: CGFloat = 268

    private let entries: [(route: Route, title: String, note: String)] = [
        (.history, "Records", "Any measurement over time, or two against each other"),
        (.nutrition, "Nutrition", "What to eat next, from your own readings"),
        (.specialists, "Specialists", "Read by an expert"),
        (.goals, "Goals", "What you're aiming at"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("❧")
                .font(Theme.serif(22))
                .foregroundStyle(Theme.amber)
                .padding(.top, 72)

            Text("The ledger")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.route) { i, entry in
                    Button {
                        Haptics.select()
                        go(entry.route)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(Theme.serif(21))
                                .foregroundStyle(Theme.ink)
                            Text(entry.note)
                                .font(Theme.sans(10))
                                .foregroundStyle(Theme.dust)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressRow)
                    // Each entry arrives after the one above it, so opening the
                    // drawer reads as a list being dealt rather than a panel
                    // appearing with things already on it.
                    .opacity(open ? 1 : 0)
                    .offset(x: open ? 0 : -14)
                    .animation(
                        Theme.Motion.flow.delay(open ? 0.06 + Double(i) * 0.045 : 0),
                        value: open
                    )
                }
            }
            .padding(.top, 26)

            Spacer()
        }
        .padding(.horizontal, 26)
        .frame(width: Self.width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.linen)
    }
}

/// The handle on the edge.
///
/// A hairline of amber at thumb height, which is the only mark on the ground
/// that is not type. Tappable as well as draggable: a drawer that opens only by
/// swiping is a drawer most people never find.
struct DrawerHandle: View {
    @Binding var open: Bool

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(Theme.Motion.flow) { open.toggle() }
        } label: {
            Capsule()
                .fill(Theme.amber)
                .frame(width: 4, height: 46)
                .padding(.vertical, 14)
                .padding(.trailing, 14)
                .padding(.leading, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("Open the ledger")
    }
}
