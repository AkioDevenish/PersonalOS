import SwiftUI
import Charts

/// The screen you open in the morning: date, briefing, the ledger.
struct HealthView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshot: HealthSnapshot?
    /// Recent days, for the comparison against your own usual weekday. Loaded
    /// separately from today so a slow history read never delays the figure
    /// the page is actually about.
    @State private var history: [HealthSnapshot] = []
    @State private var historyLoading = true
    /// Today's steps hour by hour, and the same for recent same-weekdays.
    @State private var curve: DayCurve?
    @State private var loadFailed = false
    @State private var appeared = false

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    /// The two figures a day is actually judged on.
    ///
    /// A grid of equal numbers is a table, and a table has no opinion about
    /// which of them you opened the app to see. How you slept and what your
    /// heart made of it lead, set large enough to read from a pocket.
    ///
    /// They are also the whole of Recovery & environment worth a heading, which
    /// is why that section is gone from this page: with these two lifted out it
    /// was a title over the leftovers. Steps went back to Physical activity for
    /// the same reason, so that group reads as the whole of your movement
    /// rather than the parts of it that weren't promoted.
    private var lead: [MetricSpec] {
        ["sleep", "resting_hr"]
            .compactMap { Metrics.by(id: $0) }
            .filter { spec in snapshot.flatMap { spec.value($0) } != nil }
    }

    /// Which groups this page prints. Recovery & environment is not one of
    /// them: its two figures are large at the top, and what remained under the
    /// heading was mindful minutes and headphone volume, which is not a section
    /// of a health summary. Both still live in Records and in the briefing.
    private var shownGroups: [MetricSpec.Group] {
        Metrics.populatedGroups(snapshot).filter { $0 != .recovery }
    }

    /// The groups, minus anything already shown large above it.
    private func rest(_ group: MetricSpec.Group) -> [MetricSpec] {
        Metrics.inGroup(group).filter { spec in
            snapshot.flatMap { spec.value($0) } != nil && !lead.contains(spec)
        }
    }

    var body: some View {
        let briefing = Briefing.compose(from: snapshot)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Today, and how it compares

                Kicker(text: dateKicker, color: Theme.amber, size: 11)
                    .padding(.top, 8)
                    .flowIn(0)

                hero(briefing)
                    .padding(.top, 16)
                    .flowIn(1)

                // Someone's state of mind is the softest thing the app knows:
                // it belongs in the italic, with nothing drawn around it.
                if let mood = snapshot?.stateOfMindLabels, !mood.isEmpty {
                    Text(mood.lowercased() + ".")
                        .font(Theme.serifItalic(19))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 16)
                        .flowIn(2)
                }

                // The briefing's prose lives on Home now. What stays here is
                // the way through to it, so this page is the body in figures
                // rather than the same two paragraphs a second time.
                NavigationLink(value: Route.briefing) {
                    Text("READ THE FULL BRIEFING  \u{2192}")
                        .font(Theme.sans(10, medium: true))
                        .tracking(1.8)
                        .foregroundStyle(Theme.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressRow)
                .padding(.top, 26)
                .flowIn(3)

                if !pairs.isEmpty {
                    pairGrid
                        .padding(.top, 38)
                        .flowIn(4)
                }

                if let curve, curve.today.count > 1 {
                    progress(curve)
                        .padding(.top, 44)
                        .flowIn(5)
                }

                // MARK: Everything else recorded

                ForEach(Array(shownGroups.enumerated()), id: \.element) { i, group in
                    let specs = rest(group)
                    if !specs.isEmpty {
                        SectionRule(text: group.rawValue)
                            .padding(.top, i == 0 ? 40 : 34)
                            .flowIn(6 + i)
                        grid(specs)
                            .padding(.top, 16)
                            .flowIn(6 + i)
                    }
                }

                // A refused read and a quiet day used to render identically, so
                // someone who had denied Health access saw an empty page and no
                // reason for it. The flag was being set and never read.
                if loadFailed {
                    Text("Health access was refused, so there is nothing to read. Open Settings, then Privacy and Security, then Health, and allow Personal OS.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 26)
                } else if snapshot != nil && shownGroups.isEmpty {
                    Text("Nothing recorded yet today.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 26)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
    }


    // MARK: The headline figure

    /// The one number the day is judged on.
    ///
    /// Steps where there are steps, because it is the figure people recognise
    /// without being taught to read it. Energy and sleep stand in when the day
    /// has no step count at all.
    private var headlineSpec: MetricSpec? {
        ["steps", "active_energy", "sleep"]
            .compactMap { Metrics.by(id: $0) }
            .first { spec in snapshot.flatMap { spec.value($0) } != nil }
    }

    @ViewBuilder
    private func hero(_ briefing: Briefing) -> some View {
        if let spec = headlineSpec, let snap = snapshot,
           let value = spec.value(snap), let shown = spec.display(snap) {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: spec.label, size: 9)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(shown)
                        .font(Theme.serif(62))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    if !spec.unit.isEmpty {
                        Text(spec.unit)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.dust)
                    }
                }
                .padding(.top, 4)

                if let baseline = Baseline.of(spec, history: history) {
                    Text(baseline.sentence(today: value))
                        .font(Theme.sans(13, medium: true))
                        .foregroundStyle(tint(baseline.standing(today: value)))
                        .padding(.top, 10)

                    Text(usually(spec, baseline))
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 5)
                } else if historyLoading {
                    Text("Working out your usual \(weekdayName)")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 10)
                } else {
                    // Said plainly rather than left blank: the comparison is
                    // missing because the history is, not because today was
                    // unremarkable.
                    Text("Not enough \(weekdayName)s recorded yet to say what is usual")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 10)
                }
            }
        } else {
            // Nothing measured. The briefing's own headline is the only thing
            // on the page that knows why.
            Text(briefing.headline)
                .font(Theme.serif(34))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var weekdayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private func usually(_ spec: MetricSpec, _ baseline: Baseline) -> String {
        let figure = spec.format(baseline.typical)
        let unit = spec.unit.isEmpty ? "" : " " + spec.unit
        return "Usually \(figure)\(unit), across \(baseline.samples) \(baseline.weekday)s"
    }

    private func tint(_ standing: Baseline.Standing) -> Color {
        switch standing {
        case .better:   return Theme.sage
        case .worse:    return Theme.amber
        case .ordinary: return Theme.mid
        }
    }


    // MARK: How the day has gone

    /// Today's climb against the way this weekday usually goes.
    ///
    /// Two lines and no axis furniture beyond what is needed to read them. The
    /// usual day is drawn first and quietly, because it is the thing being
    /// measured against rather than the thing being read.
    private func progress(_ curve: DayCurve) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule(text: "How the day has gone")

            Text(standing(curve))
                .font(Theme.sans(12))
                .foregroundStyle(Theme.mid)
                .padding(.top, 10)

            Chart {
                ForEach(Array(curve.typical.enumerated()), id: \.offset) { hour, value in
                    LineMark(
                        x: .value("Hour", hour),
                        y: .value("Steps", value),
                        series: .value("Series", "usual")
                    )
                    .foregroundStyle(Theme.dust.opacity(0.65))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .interpolationMethod(.monotone)
                }

                ForEach(Array(curve.today.enumerated()), id: \.offset) { hour, value in
                    AreaMark(
                        x: .value("Hour", hour),
                        y: .value("Steps", value),
                        series: .value("Series", "today")
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.amber.opacity(0.22), Theme.amber.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Hour", hour),
                        y: .value("Steps", value),
                        series: .value("Series", "today")
                    )
                    .foregroundStyle(Theme.amber)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .interpolationMethod(.monotone)
                }

                // Where the day has got to. The one point worth marking.
                if let last = curve.today.last {
                    PointMark(
                        x: .value("Hour", curve.today.count - 1),
                        y: .value("Steps", last)
                    )
                    .foregroundStyle(Theme.amber)
                    .symbolSize(60)
                }
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { value in
                    AxisValueLabel {
                        Text(clockLabel(value.as(Int.self) ?? 0))
                            .font(Theme.sans(9))
                            .foregroundStyle(Theme.dust)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        Text(MetricSpec.grouped(value.as(Double.self) ?? 0))
                            .font(Theme.sans(9))
                            .foregroundStyle(Theme.dust)
                    }
                }
            }
            .frame(height: 150)
            .padding(.top, 18)
        }
    }

    /// The sentence over the chart, in steps rather than percentages.
    private func standing(_ curve: DayCurve) -> String {
        let usual = MetricSpec.grouped(curve.typicalByNow)
        let gap = abs(curve.difference)
        // Under a couple of hundred steps apart is the same day twice.
        guard gap >= 200 else {
            return "Level with a usual \(curve.weekday) by now, which is about \(usual)"
        }
        let word = curve.difference > 0 ? "ahead of" : "behind"
        return "\(MetricSpec.grouped(gap)) \(word) a usual \(curve.weekday), which reaches \(usual) by now"
    }

    private func clockLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 12: return "noon"
        case let h where h < 12: return "\(h)am"
        default: return "\(hour - 12)pm"
        }
    }

    // MARK: The supporting figures

    /// The four that sit under the headline, whichever of them the day has.
    private var pairs: [MetricSpec] {
        ["sleep", "resting_hr", "distance", "flights", "active_energy"]
            .compactMap { Metrics.by(id: $0) }
            .filter { $0.id != headlineSpec?.id }
            .filter { spec in snapshot.flatMap { spec.value($0) } != nil }
            .prefix(4)
            .map { $0 }
    }

    private var pairGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
            ForEach(pairs) { spec in
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(text: spec.label, size: 8.5).lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(snapshot.flatMap { spec.display($0) } ?? "\u{00B7}")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        if !spec.unit.isEmpty {
                            Text(spec.unit)
                                .font(Theme.sans(9.5))
                                .foregroundStyle(Theme.dust)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Driven by the catalogue, so a metric added there appears here.
    ///
    /// No plates. The warm-white cards put a lighter rectangle behind every
    /// figure, which on a linen ground read as a box floating on paper rather
    /// than a number written on it — and fifteen of them turned the screen
    /// into a grid of tiles. The numbers now sit directly on the ground with a
    /// hairline under each, the same mark the rest of the app uses.
    private func grid(_ specs: [MetricSpec]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
        return LazyVGrid(columns: columns, spacing: 26) {
            ForEach(Array(specs.enumerated()), id: \.element.id) { index, m in
                MetricTile(spec: m, snapshot: snapshot, index: index, appeared: appeared)
            }
        }
    }

    private func load() async {
        do {
            try await health.requestAuthorization()
            snapshot = try await health.fetchTodaySnapshot()
            loadFailed = false
        } catch {
            loadFailed = true
        }
        // Drives the glyph stagger. Set after the read so the icons animate in
        // alongside their numbers rather than over an empty grid.
        withAnimation(Theme.Motion.flow) { appeared = true }

        // Eight weeks, read after today rather than alongside it. It is dozens
        // of queries for a line of supporting text, and today's figure should
        // never wait on it.
        await loadHistory()
    }

    private func loadHistory() async {
        historyLoading = true
        history = (try? await health.fetchHistoricalSnapshots(days: 56)) ?? []
        // One statistics query for eight weeks of hourly buckets, which is
        // what the curve is drawn from.
        let hourly = (try? await health.hourlySteps(days: 56)) ?? [:]
        withAnimation(Theme.Motion.flow) {
            curve = DayCurve.build(from: hourly)
            historyLoading = false
        }
    }

    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: Int(v.rounded()))) ?? "\(Int(v))"
    }

    static func duration(_ hours: Double) -> String {
        let mins = Int((hours * 60).rounded())
        return "\(mins / 60)h \(mins % 60)m"
    }
}
