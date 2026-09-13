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

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        let briefing = Briefing.compose(from: snapshot)
        let goals = Goals.progress(on: snapshot)

        return ScrollView {
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
