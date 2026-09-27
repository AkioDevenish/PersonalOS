import Foundation

/// How much of the ledger a briefing reads.
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
struct Briefing {
    let headline: String
    let paragraphs: [String]
    let suggestions: [String]

    var summary: String { paragraphs.first ?? "Connect Apple Health to begin your ledger." }

    // MARK: What the day still owes

    /// The closing list, from the goals the person actually set.
    static func owing(_ snapshot: HealthSnapshot?) -> [String] {
        let progress = Goals.progress(on: snapshot)
        guard !progress.isEmpty else { return [] }

        // A ceiling with nothing recorded is not something the day owes you.
        let unmet = progress.filter { $0.state == .missed }
        guard !unmet.isEmpty else {
            let judged = progress.filter(\.judged)
            return judged.isEmpty
                ? ["Nothing measured yet against the goals you set."]
                : ["Every goal you set for today is met."]
        }

        return unmet.map { p in
            let spec = p.spec
            let target = spec.format(p.target) + unitSuffix(spec)
            guard let actual = p.actual else {
                return "\(capitalised(spec.spoken)): nothing recorded yet, against \(target)."
            }
            let now = spec.format(actual) + unitSuffix(spec)
            let gap = p.shortfall.map { spec.format($0) + unitSuffix(spec) } ?? ""
            return spec.goal == .atMost
                ? "\(capitalised(spec.spoken)): \(now), which is \(gap) over your \(target)."
                : "\(capitalised(spec.spoken)): \(now) of \(target), \(gap) short."
        }
    }

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
                var line = "You slept \(d), which is on the short side."
                if let rhr = s.restingHeartRate {
                    line = "You slept \(d), on the short side, but your resting heart rate held at \(Int(rhr.rounded()))."
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
                paras.append("Steps stand at \(n) so far.")
                sugg.append("An easy 30-minute walk, ideally in daylight")
            } else {
                paras.append("Steps stand at \(n) so far, and the account is filling on its own.")
            }
        }

        if let energy = s.activeEnergyBurned {
            paras.append("Active energy so far: \(Int(energy.rounded())) kcal.")
        }

        if paras.isEmpty {
            // This narrative only reads sleep, steps and active energy, so a day of glucose and
            // carbohydrates and nothing else used to be called empty while the breakdown three
            // lines below listed both.
            let anything = Metrics.all.contains { $0.display(s) != nil }
            paras.append(anything
                ? "Nothing moved yet today, though the day has entries."
                : "No entries yet today. The ledger fills as you move.")
        }
        let goals = owing(s)
        if !goals.isEmpty {
            // What you set outranks what the app guessed.
            sugg = goals
        } else if sugg.isEmpty {
            sugg.append("No goals set yet. Set some and this list becomes yours.")
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
            // The window against itself: later half versus earlier.
            if let drift = drift(nights), abs(drift) >= 0.25 {
                let mins = Int((abs(drift) * 60).rounded())
                line += ", and \(drift > 0 ? "gained" : "lost") about \(mins) minutes a night as it went on"
                if drift < 0 { sugg.append("Protect the bedtime that slipped. It is costing you \(mins) minutes") }
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
                sugg.append("Add a daily walk. The average has room in it")
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
                    sugg.append("A lighter few days. The heart rate has been climbing")
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
            sugg.append("Nothing owed. The window reads steady")
        }
        return Briefing(headline: headline, paragraphs: paras, suggestions: sugg)
    }

    // MARK: The whole ledger, written out

    /// Every metric with a reading, as prose rather than as a table.
    static func breakdown(
        period: BriefingPeriod,
        today: HealthSnapshot?,
        history: [HealthSnapshot]
    ) -> [(group: MetricSpec.Group, lines: [String])] {
        MetricSpec.Group.allCases.compactMap { group in
            var sentences: [String] = []
            for spec in Metrics.inGroup(group) {
                if let line = sentence(
                    spec: spec,
                    period: period,
                    today: today,
                    history: history,
                    opening: sentences.isEmpty
                ) {
                    sentences.append(line)
                }
            }
            return sentences.isEmpty ? nil : (group, sentences)
        }
    }

    private static func sentence(
        spec: MetricSpec,
        period: BriefingPeriod,
        today: HealthSnapshot?,
        history: [HealthSnapshot],
        opening: Bool
    ) -> String? {
        let readings = history.compactMap { spec.value($0) }
        return period == .daily
            ? todaySentence(spec: spec, today: today, readings: readings, opening: opening)
            : windowSentence(spec: spec, readings: readings, period: period, opening: opening)
    }

    // MARK: One day

    private static func todaySentence(
        spec: MetricSpec,
        today: HealthSnapshot?,
        readings: [Double],
        opening: Bool
    ) -> String? {
        guard let today, let now = spec.value(today) else { return nil }
        let usual = readings.count >= 2 ? mean(readings) : nil

        if opening {
            let comparison = against(usual, now: now, spec: spec, days: readings.count)
            if spec.id == "sleep" { return "You slept \(figure(spec, now))\(comparison)." }
            return spec.cumulative
                ? "\(capitalised(spec.spoken)) came to \(figure(spec, now)) today\(comparison)."
                : "Your \(spec.spoken) read \(figure(spec, now))\(comparison)."
        }

        // Shortened: the window and the phrase "your N-day average" were established by the
        // sentence above, and repeating them five times is what made this read as a form rather
        // than a paragraph.
        guard let usual, usual > 0 else {
            return "\(capitalised(spec.spoken)) came to \(figure(spec, now))."
        }
        let delta = now - usual
        if abs(delta) / usual < 0.05 {
            return "\(capitalised(spec.spoken)) matched its usual \(figure(spec, usual))."
        }
        return "\(capitalised(spec.spoken)) reached \(figure(spec, now)) against a usual \(figure(spec, usual))."
    }

    /// Today against the days behind it.
    private static func against(
        _ baseline: Double?,
        now: Double,
        spec: MetricSpec,
        days: Int
    ) -> String {
        guard let baseline, baseline > 0, days >= 2 else { return "" }
        let delta = now - baseline
        // Under a twentieth is noise, and calling noise a change is how a briefing stops being
        // worth reading.
        guard abs(delta) / baseline >= 0.05 else {
            return ", in line with your \(days)-day average of \(figure(spec, baseline))"
        }
        let gap = difference(spec, abs(delta))
        let direction = spec.id == "sleep"
            ? (delta > 0 ? "longer than" : "short of")
            : (delta > 0 ? "above" : "below")
        return ", \(gap) \(direction) your \(days)-day average of \(figure(spec, baseline))"
    }

    // MARK: A window

    private static func windowSentence(
        spec: MetricSpec,
        readings: [Double],
        period: BriefingPeriod,
        opening: Bool
    ) -> String? {
        guard !readings.isEmpty, let avg = mean(readings) else { return nil }
        let days = "\(readings.count) recorded \(readings.count == 1 ? "day" : "days")"
        let movement = moved(readings, spec: spec, period: period, opening: opening)

        if opening {
            if spec.id == "sleep" {
                let nights = "\(readings.count) recorded \(readings.count == 1 ? "night" : "nights")"
                return "You slept \(figure(spec, avg)) a night across \(nights)\(spread(readings, spec: spec))\(movement)."
            }
            if spec.cumulative {
                let total = spec.format(readings.reduce(0, +)) + unitSuffix(spec)
                return "\(capitalised(spec.spoken)) averaged \(figure(spec, avg)) a day and came to \(total) in all across \(days)\(movement)."
            }
            return "Your \(spec.spoken) averaged \(figure(spec, avg)) over \(days)\(spread(readings, spec: spec))\(movement)."
        }

        if spec.id == "sleep" {
            return "Sleep ran to \(figure(spec, avg)) a night\(movement)."
        }
        if spec.cumulative {
            let total = spec.format(readings.reduce(0, +)) + unitSuffix(spec)
            return "\(capitalised(spec.spoken)) \(verb(spec)) \(figure(spec, avg)) a day, \(total) in all\(movement)."
        }
        return "\(capitalised(spec.spoken)) \(verb(spec)) \(figure(spec, avg))\(movement)."
    }

    /// Rotated by the metric's own id, so a paragraph doesn't say "averaged" six times.
    private static func verb(_ spec: MetricSpec) -> String {
        let verbs = ["ran to", "held at", "came in at", "averaged"]
        let seed = spec.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return verbs[seed % verbs.count]
    }

    private static func spread(_ readings: [Double], spec: MetricSpec) -> String {
        guard let lo = readings.min(), let hi = readings.max(), hi > lo else { return "" }
        return ", ranging from \(figure(spec, lo)) to \(figure(spec, hi))"
    }

    private static func moved(
        _ readings: [Double],
        spec: MetricSpec,
        period: BriefingPeriod,
        opening: Bool
    ) -> String {
        guard let d = drift(readings), let base = mean(readings), base > 0 else { return "" }
        let each = spec.cumulative ? " a day" : ""
        guard abs(d) / base >= 0.05 else {
            // Worth saying once.
            return opening ? ", holding steady throughout" : ""
        }
        let verb = d > 0 ? "rising" : "falling"
        return opening
            ? ", \(verb) by about \(difference(spec, abs(d)))\(each) as \(period.window) went on"
            : ", \(verb) about \(difference(spec, abs(d)))\(each)"
    }

    // MARK: Figures, in words

    /// "8,431" or "7h 12m" — sleep is stored in hours and reads as a decimal nowhere except a
    /// spreadsheet.
    private static func figure(_ spec: MetricSpec, _ v: Double) -> String {
        spec.id == "sleep" ? HealthView.duration(v) : spec.format(v) + unitSuffix(spec)
    }

    /// A gap between two figures, which is not always written like the figures themselves: two
    /// thirds of an hour of sleep is 40 minutes, not 0h 40m.
    private static func difference(_ spec: MetricSpec, _ v: Double) -> String {
        guard spec.id == "sleep" else { return figure(spec, v) }
        let mins = Int((v * 60).rounded())
        return mins < 60 ? "\(mins) minutes" : HealthView.duration(Double(mins) / 60)
    }

    /// A space before every unit except the percent sign, which closes up against its number in
    /// every style guide worth following.
    private static func unitSuffix(_ spec: MetricSpec) -> String {
        if spec.unit.isEmpty { return "" }
        return spec.unit == "%" ? "%" : " \(spec.unit)"
    }

    private static func capitalised(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
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

    /// Later half minus earlier half.
    private static func drift(_ values: [Double]) -> Double? {
        guard values.count >= 4 else { return nil }
        let half = values.count / 2
        guard let early = mean(Array(values.prefix(half))),
              let late = mean(Array(values.suffix(half))) else { return nil }
        return late - early
    }
}
