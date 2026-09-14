import SwiftUI

/// The landing page, and the one screen that summarises rather than reads.
///
/// Every other tab is a page of writing. This one is a dashboard, and it is
/// laid out like one: a greeting, one wide card carrying the day's read, then
/// tiles you can take in at a glance and tap into.
///
/// That means shapes with fills, which the rest of the app deliberately gave
/// up — `Plate` in Theme.swift records why, and it was right about a page of
/// prose. A summary is the exception: without something to hold them, the
/// figures on bare linen read as a list of unrelated numbers rather than
/// things you can check on. The fills are the same warm the type sits on, and
/// nothing is outlined, so the tiles lift off the ground rather than being
/// drawn onto it.
///
/// The money and hours tiles sat beside the health one until Finance and Time
/// were pulled from the bar. They are not deleted, only unbuilt: the tiles
/// went with the tabs because a tile whose whole job is to switch to a tab
/// has nowhere to send you once that tab is gone, and the two write buttons
/// under them went for the same reason — an entry you can record and never
/// read back is worse than no button at all.
struct HomeView: View {
    /// Sends you to the tab that owns a tile. The bar's selection lives in
    /// RootView, so the tile asks rather than reaches.
    var go: (AppTab) -> Void

    @EnvironmentObject private var health: HealthKitManager
    @State private var snapshot: HealthSnapshot?

    @State private var healthLoading = true

    /// Worked out when the reading changes, not while the page is drawn.
    ///
    /// Both of these used to be the first two lines of `body`. That is fine
    /// when a body runs because something changed, and not fine when it runs
    /// because a finger is moving: dragging the drawer redraws the whole page
    /// every frame, and every frame was recomposing the briefing's prose and
    /// re-deriving every goal. Neither depends on anything but the snapshot,
    /// so both are worked out once when that arrives.
    @State private var briefing = Briefing.compose(from: nil)
    @State private var goals: [Goals.Progress] = []

    private var dateKicker: String { Formatters.dayAndDate.string(from: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                    .padding(.bottom, 4)
                    .flowIn(0)

                read(briefing)
                    .flowIn(1)

                healthTile
                    .flowIn(2)

                if !goals.isEmpty {
                    goalsTile(goals).flowIn(3)
                }

                elsewhere
                    .padding(.top, 4)
                    .flowIn(4)

                Ornament()
                    .padding(.top, 34)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Theme.linen)
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: The page

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(text: dateKicker, color: Theme.amber, size: 11)
            Text("Your ledger.")
                .font(Theme.serif(34))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    /// The day's read, and the only tile with prose in it.
    private func read(_ briefing: Briefing) -> some View {
        NavigationLink(value: Route.briefing) {
            Tile {
                VStack(alignment: .leading, spacing: 12) {
                    Text(briefing.headline)
                        .font(Theme.serif(26))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    if let opening = briefing.paragraphs.first {
                        Text(opening)
                            .font(Theme.serifBody(16))
                            .foregroundStyle(Theme.mid)
                            .lineSpacing(5)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    Text("READ THE FULL BRIEFING  →")
                        .font(Theme.sans(9.5, medium: true))
                        .tracking(1.8)
                        .foregroundStyle(Theme.amber)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.pressRow)
    }

    private var healthTile: some View {
        Button {
            Haptics.select()
            go(.health)
        } label: {
            Tile {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Kicker(text: "Health", size: 9)
                        figure(healthFigure, loading: healthLoading)
                        // A tile still reading has not learned there is
                        // nothing; saying so before the answer arrives is a
                        // guess dressed as a fact.
                        Text(healthLoading ? "Reading" : healthNote)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.mid)
                    }
                    Spacer(minLength: 0)
                    glyph("heart", Theme.amber)
                }
            }
        }
        .buttonStyle(.pressRow)
    }

    /// Everything that isn't today.
    ///
    /// These five were behind a drawer, which hid three of the app's verbs
    /// behind a gesture nobody had been told about — a risk LedgerDrawer's own
    /// comment named when it was built. On the page they are simply there.
    ///
    /// Paired across two columns, with an odd one left full width rather than
    /// floated beside a gap. Nothing here carries a figure: a card that had to
    /// read a ledger to draw itself would make opening the app wait on five
    /// answers, and the cycle would put a permission prompt on the home
    /// screen, which is exactly where it should not be.
    private var elsewhere: some View {
        VStack(spacing: 14) {
            ForEach(Array(Self.places.chunked(into: 2).enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(pair, id: \.route) { place in
                        placeCard(place)
                    }
                    // A single card on the last row takes the full width; an
                    // invisible partner would leave it half-wide beside a hole.
                }
            }
        }
    }

    private struct Place {
        let route: Route
        let title: String
        let note: String
        let symbol: String
    }

    private static let places: [Place] = [
        .init(route: .history, title: "Records", note: "Any measurement, over time", symbol: "chart.xyaxis.line"),
        .init(route: .nutrition, title: "Nutrition", note: "What to eat next", symbol: "leaf"),
        .init(route: .specialists, title: "Specialists", note: "Read on this phone", symbol: "sparkles"),
        .init(route: .professionals, title: "Practitioners", note: "Real people you can ask", symbol: "person.2"),
        .init(route: .cycle, title: "Cycle", note: "Kept on this phone only", symbol: "circle.dotted"),
    ]

    private func placeCard(_ place: Place) -> some View {
        NavigationLink(value: place.route) {
            Tile {
                VStack(alignment: .leading, spacing: 10) {
                    glyph(place.symbol, Theme.amber, size: 16)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.title)
                            .font(Theme.serif(20))
                            .foregroundStyle(Theme.ink)
                        Text(place.note)
                            .font(Theme.sans(10.5))
                            .foregroundStyle(Theme.dust)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // Fills the row's height so a pair whose notes wrap to
                // different depths still reads as two cards of one size
                // rather than one card and a short one.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(.pressRow)
    }

    /// Goals as a row of marks rather than a number.
    ///
    /// "3 of 5" makes you do the arithmetic to find out whether that is a good
    /// day. Five marks, lit or not, is the same fact already answered.
    private func goalsTile(_ goals: [Goals.Progress]) -> some View {
        NavigationLink(value: Route.goals) {
            Tile {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Kicker(text: "Goals", size: 9)
                        Spacer(minLength: 0)
                        Text("\(goals.filter(\.met).count) of \(goals.count) kept")
                            .font(Theme.sans(11, medium: true))
                            .foregroundStyle(Theme.mid)
                    }
                    HStack(spacing: 6) {
                        ForEach(goals) { g in
                            Capsule()
                                .fill(mark(for: g.state))
                                .frame(height: 5)
                        }
                    }
                }
            }
        }
        .buttonStyle(.pressRow)
    }

    private func mark(for state: Goals.Progress.State) -> Color {
        switch state {
        case .met: return Theme.sage
        // A ceiling nothing was measured against is not a failure, and colouring
        // it like one tells people they broke a limit they never tested.
        case .unmeasured: return Theme.hairline
        case .missed: return Theme.amber.opacity(0.45)
        }
    }

    // MARK: Small parts

    private func figure(_ text: String?, loading: Bool, size: CGFloat = 32) -> some View {
        Group {
            if loading {
                Text("·")
                    .font(Theme.serif(size))
                    .foregroundStyle(Theme.dust)
            } else if let text {
                Text(text)
                    .font(Theme.serif(size))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            } else {
                // Nothing to report shows nothing. A row announcing "None" in
                // serif is a page shouting that it knows nothing, and the line
                // underneath already says so once, quietly.
                Color.clear.frame(height: 1)
            }
        }
    }

    private func glyph(_ name: String, _ tint: Color, size: CGFloat = 19) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(tint)
            .environment(\.symbolVariants, .none)
    }

    // MARK: What each tile says

    private var headline: MetricSpec? {
        guard let snapshot else { return nil }
        return ["steps", "sleep", "resting_hr"]
            .compactMap { Metrics.by(id: $0) }
            .first { $0.display(snapshot) != nil }
    }

    private var healthFigure: String? {
        guard let snapshot, let spec = headline else { return nil }
        return spec.display(snapshot)
    }

    private var healthNote: String {
        guard let spec = headline else { return "Nothing recorded yet today" }
        return (spec.phrase ?? spec.label).lowercased() + " today"
    }

    // MARK: Behaviour

    private func load() async {
        snapshot = try? await health.fetchTodaySnapshot()
        briefing = Briefing.compose(from: snapshot)
        goals = Goals.progress(on: snapshot)
        healthLoading = false
    }
}

/// The dashboard's one shape.
///
/// Warm on linen, generously rounded, no border. The lift is a couple of
/// percent of brightness, which is enough to say "this is one thing" without
/// drawing a box around it — a stroke here would put a grid of frames on a
/// page whose whole argument is that it is written rather than filled in.
private struct Tile<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.warm, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

extension Array {
    /// Fixed-size runs, for laying a list out in columns.
    ///
    /// The last run is short rather than padded, which is what lets a lone
    /// card take the full width instead of sitting half-wide beside nothing.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
