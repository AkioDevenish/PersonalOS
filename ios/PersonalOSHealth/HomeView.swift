import SwiftUI

/// The landing page, and the only screen that looks across all three ledgers.
///
/// Health keeps the body in detail, Finance the money, Time the hours. This one
/// answers the question you open the app with, which is none of those
/// separately: what kind of day is this, and is anything out of place. One
/// figure from each, and a way through to whichever one you actually came for.
struct HomeView: View {
    /// Sends you to the tab that owns a row. The bar's selection lives in
    /// RootView, so the row asks rather than reaches.
    var go: (AppTab) -> Void

    @EnvironmentObject private var health: HealthKitManager
    @AppStorage("ledger_currency") private var currency = Money.deviceDefault

    @State private var snapshot: HealthSnapshot?
    @State private var moneyLedger = FinanceClient.Ledger.empty
    @State private var timeLedger = TimeClient.Ledger.empty
    // One flag per ledger rather than one for the page. HealthKit can take
    // its time, or on a simulator never answer at all, and a single flag let
    // it hold the money and the hours hostage: the whole section sat in the
    // shimmer waiting on a read that was never coming back.
    @State private var healthLoading = true
    @State private var moneyLoading = true
    @State private var timeLoading = true

    private let finance = FinanceClient()
    private let clock = TimeClient()

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        let briefing = Briefing.compose(from: snapshot)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: dateKicker, color: Theme.amber, size: 11)
                    .padding(.top, 8)
                    .flowIn(0)

                Text(briefing.headline)
                    .font(Theme.serif(38))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .flowIn(1)

                // One paragraph here, not two. The full read is a tap away and
                // has a whole screen to itself; this page's job is to say
                // enough that you know whether you need it.
                if let opening = briefing.paragraphs.first {
                    NavigationLink(value: Route.briefing) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(
                                emphasising: opening,
                                base: Theme.serifBody(18),
                                strong: Theme.serif(20)
                            )
                            .lineSpacing(7)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                            Text("READ THE FULL BRIEFING  →")
                                .font(Theme.sans(10, medium: true))
                                .tracking(1.8)
                                .foregroundStyle(Theme.amber)
                        }
                    }
                    .buttonStyle(.pressRow)
                    .padding(.top, 24)
                    .flowIn(2)
                }

                SectionRule(text: "Across the ledger")
                    .padding(.top, 46)
                    .padding(.bottom, 4)
                    .flowIn(3)

                row("Health", healthFigure, healthNote, .health, healthLoading).flowIn(4)
                row("Money", moneyFigure, moneyNote, .finance, moneyLoading).flowIn(5)
                row("Time", timeFigure, timeNote, .time, timeLoading).flowIn(6)

                Ornament()
                    .padding(.top, 48)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 26)
            .padding(.top, 10)
        }
        .background(Theme.linen)
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: A row per ledger

    private func row(
        _ title: String,
        _ figure: String?,
        _ note: String,
        _ tab: AppTab,
        _ loading: Bool
    ) -> some View {
        Button {
            Haptics.select()
            go(tab)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.sans(11, medium: true))
                        .foregroundStyle(Theme.dust)
                    Text(loading ? "Reading" : note)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                }
                Spacer(minLength: 8)
                if loading {
                    Text("·")
                        .font(Theme.serif(28))
                        .foregroundStyle(Theme.dust)
                } else if let figure {
                    Text(figure)
                        .font(Theme.serif(28))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }

    // MARK: What each row says

    /// Steps if the day has them, sleep if it doesn't. Both are figures a
    /// person recognises without a chart.
    private var headline: MetricSpec? {
        guard let snapshot else { return nil }
        return ["steps", "sleep", "resting_hr"]
            .compactMap { Metrics.by(id: $0) }
            .first { $0.display(snapshot) != nil }
    }

    /// Nil rather than a word meaning nil. Three rows each announcing "None"
    /// in 28pt serif is a page shouting that it knows nothing; the quiet line
    /// underneath already says so, once, in the right register.
    private var healthFigure: String? {
        guard let snapshot, let spec = headline else { return nil }
        return spec.display(snapshot)
    }

    private var healthNote: String {
        guard let spec = headline else { return "Nothing recorded yet" }
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
        // Three independent reads, each landing on its own row as it arrives.
        // Awaiting all three together meant the slowest decided when any of
        // them appeared, and a read that never returns meant never.
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
