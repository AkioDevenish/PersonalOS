import SwiftUI

/// How much of the ledger a briefing reads.
///
/// Not just three lengths of the same paragraph: a day is a report of what
/// happened, and a month is a report of what is happening — an average, a
/// direction, a best day. The prose is written separately for each because the
/// honest sentence about one day ("you slept 5h 40m") is a dishonest one about
/// thirty ("you slept 5h 40m" every night?).
enum BriefingPeriod: String, CaseIterable, Identifiable {
    case daily, weekly, monthly

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .monthly: return 30
        }
    }

    var label: String {
        switch self {
        case .daily: return "Morning briefing"
        case .weekly: return "The week"
        case .monthly: return "The month"
        }
    }

    /// What the closing list is asking you to spend.
    var spend: String {
        switch self {
        case .daily: return "Spend today on"
        case .weekly: return "Spend the week on"
        case .monthly: return "Spend the month on"
        }
    }

    var window: String {
        switch self {
        case .daily: return "today"
        case .weekly: return "the last seven days"
        case .monthly: return "the last thirty days"
        }
    }
}

/// The briefing content, composed on-device from recorded snapshots.
///
/// This is deliberately rule-based for now: honest sentences derived from
/// real numbers. When the server's AI reports move off SQLite, this struct
/// is the seam where they arrive — same shape, better prose.
struct Briefing {
    let headline: String
    let paragraphs: [String]
    let suggestions: [String]

    var summary: String { paragraphs.first ?? "Connect Apple Health to begin your ledger." }

    // MARK: A day

    static func compose(from s: HealthSnapshot?) -> Briefing {
        guard let s else {
            return Briefing(
                headline: "The ledger is empty.",
                paragraphs: ["Allow Health access and today's entries will write themselves."],
                suggestions: ["Allow Health access from Settings"]
            )
        }
        var paras: [String] = []
        var sugg: [String] = []
        var headline = "The day, in ink."

        // zero total is "no samples", not a measured night
        if let sleep = s.totalSleepHours, sleep > 0 {
            let d = HealthView.duration(sleep)
            if sleep < 6.5 {
                headline = "A short night."
                var line = "You slept \(d) — on the short side."
                if let rhr = s.restingHeartRate {
                    line = "You slept \(d) — on the short side — but your resting heart rate held at \(Int(rhr.rounded()))."
                    headline = "A short night,\nsteady heart."
                }
                paras.append(line)
                sugg.append("Lights out earlier tonight to repay the hour")
            } else {
                headline = "A well-kept night."
                paras.append("You slept \(d), and the ledger opens in credit.")
            }
        }

        if let steps = s.steps {
            let n = HealthView.grouped(steps)
            if steps < 4000 {
                paras.append("Steps stand at \(n) so far — the day still owes you a walk.")
                sugg.append("An easy 30-minute walk, ideally in daylight")
            } else {
                paras.append("Steps stand at \(n) so far — the account is filling on its own.")
            }
        }

        if let energy = s.activeEnergyBurned {
            paras.append("Active energy so far: \(Int(energy.rounded())) kcal.")
        }

        if paras.isEmpty {
            paras.append("No entries yet today — the ledger fills as you move.")
        }
        if sugg.isEmpty {
            sugg.append("Nothing owed — spend the day as you like")
        }
        return Briefing(headline: headline, paragraphs: paras, suggestions: sugg)
    }

    // MARK: A window

    static func compose(period: BriefingPeriod, snapshots: [HealthSnapshot]) -> Briefing {
        guard period != .daily else {
            return compose(from: snapshots.last)
        }

        let recorded = snapshots.filter { snap in
            Metrics.all.contains { $0.value(snap) != nil }
        }
        guard recorded.count >= 2 else {
            return Briefing(
                headline: "Not enough kept yet.",
                paragraphs: [
                    "\(period == .weekly ? "A week" : "A month") needs more than \(recorded.count) recorded \(recorded.count == 1 ? "day" : "days") before an average means anything. Wear your watch and this fills itself in."
                ],
                suggestions: ["Keep the watch on overnight to record sleep"]
            )
        }

        var paras: [String] = []
        var sugg: [String] = []
        var headline = period == .weekly ? "The week, in ink." : "The month, in ink."

        let nights = values(recorded, "sleep")
        if let avgSleep = mean(nights) {
            let d = HealthView.duration(avgSleep)
            var line = "You slept \(d) a night across \(nights.count) recorded \(nights.count == 1 ? "night" : "nights")"
            // The window against itself: later half versus earlier. A trend
            // inside the period is a claim the data can actually support,
            // where "against last month" would need history this doesn't hold.
            if let drift = drift(nights), abs(drift) >= 0.25 {
                let mins = Int((abs(drift) * 60).rounded())
                line += ", and \(drift > 0 ? "gained" : "lost") about \(mins) minutes a night as it went on"
                if drift < 0 { sugg.append("Protect the bedtime that slipped — it's costing you \(mins) minutes") }
            }
            paras.append(line + ".")

            if avgSleep < 6.5 {
                headline = period == .weekly ? "A short-slept week." : "A short-slept month."
                sugg.append("An earlier night, three times this week")
            } else if avgSleep >= 7.5 {
                headline = period == .weekly ? "A well-kept week." : "A well-kept month."
            }
        }

        let steps = values(recorded, "steps")
        if let avgSteps = mean(steps), let best = peak(recorded, "steps") {
            var line = "Steps averaged \(HealthView.grouped(avgSteps)) a day"
            line += ", \(HealthView.grouped(steps.reduce(0, +))) in all"
            line += ", with your best on \(best.date.formatted(.dateTime.day().month(.abbreviated))) at \(HealthView.grouped(best.value))."
            paras.append(line)
            if avgSteps < 5000 {
                sugg.append("Add a daily walk — the average has room in it")
            }
        }

        if let avgEnergy = mean(values(recorded, "active_energy")) {
            paras.append("Active energy ran to \(Int(avgEnergy.rounded())) kcal a day.")
        }

        let rhr = values(recorded, "resting_hr")
        if let avgRhr = mean(rhr) {
            var line = "Your resting heart rate averaged \(Int(avgRhr.rounded())) bpm"
            if let drift = drift(rhr), abs(drift) >= 1 {
                line += ", drifting \(drift > 0 ? "up" : "down") about \(Int(abs(drift).rounded())) bpm across \(period.window)"
                if drift > 2 {
                    sugg.append("A lighter few days — the heart rate has been climbing")
                }
            }
            paras.append(line + ".")
        }

        if let avgGlucose = mean(values(recorded, "glucose")) {
            paras.append("Blood glucose averaged \(Int(avgGlucose.rounded())) mg/dL over the days it was recorded.")
        }

        if paras.isEmpty {
            paras.append("Nothing measurable was recorded over \(period.window).")
        }
        if sugg.isEmpty {
            sugg.append("Nothing owed — the window reads steady")
        }
        return Briefing(headline: headline, paragraphs: paras, suggestions: sugg)
    }

    // MARK: Arithmetic

    private static func values(_ snaps: [HealthSnapshot], _ id: String) -> [Double] {
        guard let spec = Metrics.by(id: id) else { return [] }
        return snaps.compactMap { spec.value($0) }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func peak(_ snaps: [HealthSnapshot], _ id: String) -> (date: Date, value: Double)? {
        guard let spec = Metrics.by(id: id) else { return nil }
        return snaps
            .compactMap { snap in spec.value(snap).map { (snap.recordedAt, $0) } }
            .max { $0.1 < $1.1 }
    }

    /// Later half minus earlier half. Needs four readings to mean anything —
    /// two points either side, or one day's oddity becomes "a trend".
    private static func drift(_ values: [Double]) -> Double? {
        guard values.count >= 4 else { return nil }
        let half = values.count / 2
        guard let early = mean(Array(values.prefix(half))),
              let late = mean(Array(values.suffix(half))) else { return nil }
        return late - early
    }
}

struct BriefingView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var period: BriefingPeriod = .daily
    @State private var snapshots: [HealthSnapshot] = []
    @State private var loading = true

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var kicker: String {
        period == .daily ? "\(period.label) · \(dateLine)" : "\(period.label) · \(period.window)"
    }

    var body: some View {
        let b = Briefing.compose(period: period, snapshots: snapshots)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The briefing is the one screen that is purely something to
                // read, so it's written onto the page a line at a time rather
                // than handed over whole. The stagger is the same 50ms step
                // the metric grid uses; the paragraphs continue the count so
                // the whole page reads as one movement down.
                Kicker(text: kicker, color: Theme.amber)
                    .padding(.top, 12)
                    .flowIn(0)

                PillPicker(values: BriefingPeriod.allCases, selection: $period) { $0.rawValue }
                    .onSelect { Task { await load() } }
                    .padding(.top, 16)
                    .flowIn(1)

                Text(b.headline)
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 18)
                    .flowIn(2)

                ForEach(Array(b.paragraphs.enumerated()), id: \.element) { i, p in
                    Text(p)
                        .font(Theme.serifBody(18))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .padding(.top, 16)
                        .flowIn(3 + i)
                }

                Ornament()
                    .padding(.vertical, 26)
                    .flowIn(3 + b.paragraphs.count)

                Kicker(text: period.spend)
                    .flowIn(4 + b.paragraphs.count)

                ForEach(Array(b.suggestions.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(["I", "II", "III", "IV"][min(i, 3)])
                            .font(Theme.serif(17))
                            .foregroundStyle(Theme.amber)
                            .frame(width: 22, alignment: .leading)
                        Text(s)
                            .font(Theme.serifBody(17))
                            .foregroundStyle(Theme.mid)
                            .lineSpacing(5)
                    }
                    .padding(.top, 14)
                    .flowIn(5 + b.paragraphs.count + i)
                }

                Spacer(minLength: 40)
            }
            // Switching period rewrites the whole page. Animating on the value
            // rather than at the tap keeps the paragraphs moving as one.
            .animation(Theme.Motion.flow, value: period)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .toolbarBackground(Theme.linen, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            try await health.requestAuthorization()
            // A day still reads from today's live snapshot rather than
            // yesterday's stored one — the morning briefing is about a day in
            // progress, and the history read only holds completed days.
            snapshots = period == .daily
                ? [try await health.fetchTodaySnapshot()]
                : try await health.fetchHistoricalSnapshots(days: period.days)
        } catch {
            snapshots = []
        }
    }
}
