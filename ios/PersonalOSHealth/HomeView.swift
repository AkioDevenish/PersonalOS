import SwiftUI

/// The landing page, and the only screen that looks across all three ledgers.
///
/// Every other tab is a page of writing. This one is a dashboard, and it is
/// laid out like one: a greeting, one wide card carrying the day's read, then
/// tiles you can take in at a glance and tap into.
///
/// That means shapes with fills, which the rest of the app deliberately gave
/// up — `Plate` in Theme.swift records why, and it was right about a page of
/// prose. A summary is the exception: without something to hold them, six
/// figures on bare linen read as a list of unrelated numbers rather than four
/// things you can check on. The fills are the same warm the type sits on, and
/// nothing is outlined, so the tiles lift off the ground rather than being
/// drawn onto it.
struct HomeView: View {
    /// Sends you to the tab that owns a tile. The bar's selection lives in
    /// RootView, so the tile asks rather than reaches.
    var go: (AppTab) -> Void

    @EnvironmentObject private var health: HealthKitManager
    @AppStorage("ledger_currency") private var currency = Money.deviceDefault

    @State private var snapshot: HealthSnapshot?
    @State private var moneyLedger = FinanceClient.Ledger.empty
    @State private var timeLedger = TimeClient.Ledger.empty

    // One flag per ledger rather than one for the page. HealthKit can take its
    // time, or on a simulator never answer at all, and a single flag let it
    // hold the money and the hours hostage behind a read never coming back.
    @State private var healthLoading = true
    @State private var moneyLoading = true
    @State private var timeLoading = true

    @State private var writingMoney = false
    @State private var writingTime = false

    private let finance = FinanceClient()
    private let clock = TimeClient()

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

                HStack(spacing: 14) {
                    moneyTile
                    timeTile
                }
                .flowIn(3)

                if !goals.isEmpty {
                    goalsTile(goals).flowIn(4)
                }

                writeRow
                    .padding(.top, 6)
                    .flowIn(5)

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
        .sheet(isPresented: $writingMoney) {
            FinanceEntrySheet(currency: currency) { date, minor, category, note in
                try await finance.add(
                    date: date, minor: minor, currency: currency,
                    category: category, note: note
                )
                await loadMoney()
            }
        }
        .sheet(isPresented: $writingTime) {
            TimeBlockSheet { start, minutes, activity, category, note in
                try await clock.add(
                    start: start, minutes: minutes, activity: activity,
                    category: category, note: note
                )
                await loadTime()
            }
        }
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

    private var moneyTile: some View {
        Button {
            Haptics.select()
            go(.finance)
        } label: {
            Tile {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Kicker(text: "Money", size: 9)
                        Spacer(minLength: 0)
                        glyph("dollarsign", Theme.amber, size: 15)
                    }
                    figure(moneyFigure, loading: moneyLoading, size: 26)
                    Text(moneyLoading ? "Reading" : moneyNote)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.mid)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.pressRow)
    }

    private var timeTile: some View {
        Button {
            Haptics.select()
            go(.time)
        } label: {
            Tile {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Kicker(text: "Time", size: 9)
                        Spacer(minLength: 0)
                        glyph("clock", Theme.sage, size: 15)
                    }
                    figure(timeFigure, loading: timeLoading, size: 26)
                    Text(timeLoading ? "Reading" : timeNote)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.mid)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    /// The two things you might have opened the app to write down.
    private var writeRow: some View {
        HStack(spacing: 12) {
            writeButton("Record an entry") { writingMoney = true }
            writeButton("Log some time") { writingTime = true }
        }
    }

    private func writeButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.sans(12, medium: true))
                .foregroundStyle(Theme.warm)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.press)
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

    private var moneyFigure: String? {
        guard let t = moneyLedger.totals.first(where: { $0.currency == currency })
                ?? moneyLedger.totals.first else { return nil }
        return Money.text(t.net, t.currency, showingSign: true)
    }

    private var moneyNote: String {
        moneyLedger.entries.isEmpty ? "Nothing written this week" : "net this week"
    }

    private var timeFigure: String? {
        timeLedger.blocks.isEmpty ? nil : Duration.hours(timeLedger.totalMinutes) + "h"
    }

    private var timeNote: String {
        timeLedger.blocks.isEmpty ? "Nothing logged this week" : "logged this week"
    }

    // MARK: Behaviour

    private func load() async {
        // Three independent reads, each landing on its own tile as it arrives.
        // Awaiting all three together meant the slowest decided when any of
        // them appeared, and one that never returns meant never.
        async let body: Void = loadHealth()
        async let purse: Void = loadMoney()
        async let hours: Void = loadTime()
        _ = await (body, purse, hours)
    }

    private func loadHealth() async {
        snapshot = try? await health.fetchTodaySnapshot()
        healthLoading = false
    }

    private func loadMoney() async {
        let week = LedgerSpan.week.window()
        moneyLedger = (try? await finance.ledger(from: week.from, to: week.to)) ?? .empty
        moneyLoading = false
    }

    private func loadTime() async {
        let week = LedgerSpan.week.window()
        timeLedger = (try? await clock.ledger(from: week.from, to: week.to)) ?? .empty
        timeLoading = false
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
