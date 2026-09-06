import SwiftUI
import Charts

/// History: any measurement over time, and any two of them against each other.
///
/// This was two screens. Trends could draw four hardcoded series — steps,
/// sleep, resting heart rate, active energy — while Correlations, sitting one
/// row below it in the same list, could reach all nineteen. So the screen whose
/// whole job was showing a measurement over time was the one that couldn't show
/// you your walking steadiness, and the way to chart it was to open the other
/// screen and correlate it against something you didn't care about.
///
/// One screen now, and one idea: pick a measurement and read it. Pick a second
/// and the same chart becomes the comparison, with Pearson's r underneath. Both
/// pickers are the catalogue, so anything the app records can be read either
/// way.
///
/// Deliberately reads HealthKit directly rather than the server. The charts are
/// then honest about what the phone actually holds, work with no network, and
/// don't wait on a sync having happened.
struct TrendsView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshots: [HealthSnapshot] = []
    @State private var days = 30
    @State private var primary: MetricSpec = Metrics.by(id: "steps") ?? Metrics.all[0]
    /// Nil is the normal state, not a missing value: most readings are one
    /// measurement over time. Setting it turns the screen into the comparison.
    @State private var against: MetricSpec?
    @State private var loading = true
    @State private var picking: Slot?

    private enum Slot: Int, Identifiable {
        case primary, against
        var id: Int { rawValue }
    }

    private var comparing: Bool { against != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "History", color: Theme.amber, size: 11)
                    .padding(.top, 8)
                    .flowIn(0)

                Text(comparing ? "Does one follow\nthe other?" : "The ledger's past.")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 8)
                    .flowIn(0)

                pickers.padding(.top, 22).flowIn(1)

                PillPicker(values: [7, 30, 90], selection: $days) { "\($0) days" }
                    .onSelect { Task { await load() } }
                    .padding(.top, 16)
                    .flowIn(2)

                chart.padding(.top, 24).flowIn(3)

                summary.padding(.top, 22).flowIn(4)

                Spacer(minLength: 40)
            }
            .animation(Theme.Motion.flow, value: against?.id)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $picking) { slot in
            MetricPicker(
                title: slot == .primary ? "Read" : "Compare with",
                selected: slot == .primary ? primary : against,
                // Only the second slot may be empty: a chart of nothing
                // against nothing isn't a reading.
                clearable: slot == .against
            ) { chosen in
                Haptics.select()
                withAnimation(Theme.Motion.bouncy) {
                    if slot == .primary {
                        primary = chosen ?? primary
                    } else {
                        against = chosen
                    }
                }
                picking = nil
            }
        }
    }

    // MARK: Choosing

    private var pickers: some View {
        VStack(spacing: 0) {
            pickerRow(label: "Reading", metric: primary.label, colour: Theme.ink) {
                picking = .primary
            }
            pickerRow(
                label: "Compare with",
                metric: against?.label ?? "Nothing",
                colour: comparing ? Theme.amber : Theme.hairline
            ) {
                picking = .against
            }
        }
    }

    private func pickerRow(
        label: String,
        metric: String,
        colour: Color,
        tap: @escaping () -> Void
    ) -> some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                Circle().fill(colour).frame(width: 8, height: 8)
                Kicker(text: label, size: 9)
                Spacer()
                Text(metric)
                    .font(Theme.serif(19))
                    .foregroundStyle(metric == "Nothing" ? Theme.dust : Theme.ink)
                    .contentTransition(.opacity)
                Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }

    // MARK: Reading

    private func points(_ spec: MetricSpec) -> [(date: Date, value: Double)] {
        snapshots.compactMap { s in
            guard let v = spec.value(s) else { return nil }
            return (s.recordedAt, v)
        }
    }

    /// Only days where both metrics have a value — a correlation over gaps is
    /// not a correlation.
    private var pairs: [(date: Date, a: Double, b: Double)] {
        guard let against else { return [] }
        return snapshots.compactMap { s in
            guard let va = primary.value(s), let vb = against.value(s) else { return nil }
            return (s.recordedAt, va, vb)
        }
    }

    @ViewBuilder
    private var chart: some View {
        if loading {
            placeholder("Reading your history…")
        } else if comparing && pairs.isEmpty {
            placeholder("No days in this window have both readings.")
        } else if !comparing && points(primary).isEmpty {
            placeholder("No \(primary.label.lowercased()) recorded in this window.")
        } else if comparing {
            comparisonChart
        } else {
            singleChart
        }
    }

    /// One measurement, on its own axis and in its own units.
    private var singleChart: some View {
        let series = points(primary)
        return Chart {
            ForEach(series, id: \.date) { p in
                if primary.cumulative {
                    BarMark(
                        x: .value("Day", p.date, unit: .day),
                        y: .value(primary.label, p.value)
                    )
                    .foregroundStyle(Theme.amber.opacity(0.75))
                } else {
                    LineMark(
                        x: .value("Day", p.date, unit: .day),
                        y: .value(primary.label, p.value)
                    )
                    .foregroundStyle(Theme.ink)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Day", p.date, unit: .day),
                        y: .value(primary.label, p.value)
                    )
                    .foregroundStyle(Theme.amber)
                    .symbolSize(18)
                }
            }

            if let avg = average(series.map(\.value)) {
                RuleMark(y: .value("Average", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Theme.dust)
            }
        }
        .chartYAxis { ledgerYAxis }
        .chartXAxis { ledgerXAxis }
        .frame(height: 220)
        // Bars and lines are different marks, and asking Charts to morph one
        // into the other looks like a mistake. Redrawn on a cross-fade.
        .id("single-\(primary.id)")
        .transition(.opacity)
    }

    /// Two measurements, normalised onto a shared 0–1 scale before plotting.
    ///
    /// Steps run to five figures and resting heart rate to two; drawn on one
    /// axis the smaller series would flatten into the baseline and look like
    /// nothing was happening. The plates underneath keep the real numbers, and
    /// Pearson's r is computed on the raw values, never the normalised ones.
    private var comparisonChart: some View {
        let rows = pairs
        let na = normalise(rows.map(\.a))
        let nb = normalise(rows.map(\.b))
        return Chart {
            ForEach(Array(rows.enumerated()), id: \.element.date) { i, p in
                LineMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("First", na[i]),
                    series: .value("Series", "a")
                )
                .foregroundStyle(Theme.ink)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("Second", nb[i]),
                    series: .value("Series", "b")
                )
                .foregroundStyle(Theme.amber)
                .interpolationMethod(.catmullRom)
            }
        }
        // The axis is a shared 0–1 scale that belongs to neither measurement,
        // so labelling it with numbers would invite reading them as values.
        .chartYAxis(.hidden)
        .chartXAxis { ledgerXAxis }
        .frame(height: 220)
        .id("pair-\(primary.id)-\(against?.id ?? "")")
        .transition(.opacity)
    }

    private var ledgerYAxis: some AxisContent {
        AxisMarks(position: .leading) { _ in
            AxisGridLine().foregroundStyle(Theme.hairline)
            AxisValueLabel().font(Theme.sans(9)).foregroundStyle(Theme.dust)
        }
    }

    private var ledgerXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: days > 14 ? 7 : 2)) { _ in
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .font(Theme.sans(9))
                .foregroundStyle(Theme.dust)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(12))
            .foregroundStyle(Theme.dust)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
    }

    // MARK: Saying what it means

    @ViewBuilder
    private var summary: some View {
        if comparing {
            if let r = pearson {
                Plate {
                    VStack(alignment: .leading, spacing: 8) {
                        Kicker(text: "Pearson's r", size: 9)
                        Text(String(format: "%.2f", r))
                            .font(Theme.serif(34))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text(interpretation(r))
                            .font(Theme.serifBody(16))
                            .foregroundStyle(Theme.mid)
                            .lineSpacing(5)
                        Text("Over \(pairs.count) days with both readings. Association, not cause.")
                            .font(Theme.sans(10.5))
                            .foregroundStyle(Theme.dust)
                    }
                }
            }
        } else {
            let values = points(primary).map(\.value)
            HStack(spacing: 13) {
                statPlate("Average", average(values))
                statPlate("Best", values.max())
            }
        }
    }

    private func statPlate(_ label: String, _ value: Double?) -> some View {
        Plate {
            VStack(alignment: .leading, spacing: 5) {
                Kicker(text: label, size: 9)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value.map { format($0) } ?? "·")
                        .font(Theme.serif(28))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    if !primary.unit.isEmpty {
                        Text(primary.unit)
                            .font(Theme.sans(10))
                            .foregroundStyle(Theme.dust)
                    }
                }
            }
        }
    }

    private func format(_ v: Double) -> String {
        primary.precision == 0
            ? MetricSpec.grouped(v)
            : String(format: "%.\(primary.precision)f", v)
    }

    private func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// Scales a series into 0–1 so two different magnitudes share an axis.
    private func normalise(_ values: [Double]) -> [Double] {
        guard let lo = values.min(), let hi = values.max(), hi > lo else {
            return values.map { _ in 0.5 }
        }
        return values.map { ($0 - lo) / (hi - lo) }
    }

    /// Pearson's r on the raw values.
    private var pearson: Double? {
        let rows = pairs
        guard rows.count >= 3 else { return nil }
        let xs = rows.map(\.a), ys = rows.map(\.b)
        let n = Double(rows.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var num = 0.0, dx = 0.0, dy = 0.0
        for i in rows.indices {
            let a = xs[i] - mx, b = ys[i] - my
            num += a * b
            dx += a * a
            dy += b * b
        }
        guard dx > 0, dy > 0 else { return nil }
        return num / (dx * dy).squareRoot()
    }

    private func interpretation(_ r: Double) -> String {
        let a = primary.label.lowercased()
        let b = (against?.label ?? "").lowercased()
        let strength: String
        switch abs(r) {
        case ..<0.2: strength = "almost nothing"
        case ..<0.4: strength = "a faint"
        case ..<0.6: strength = "a moderate"
        case ..<0.8: strength = "a strong"
        default: strength = "a very strong"
        }
        if abs(r) < 0.2 {
            return "Over this window, \(a) and \(b) show \(strength) in common."
        }
        return r > 0
            ? "Over this window there is \(strength) tendency for \(b) to be higher on the days your \(a) is higher."
            : "Over this window there is \(strength) tendency for \(b) to be lower on the days your \(a) is higher."
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            try await health.requestAuthorization()
            snapshots = try await health.fetchHistoricalSnapshots(days: days)
        } catch {
            snapshots = []
        }
    }
}

/// The catalogue, as a sheet.
///
/// Both slots pick from the same list, because both are the same question —
/// which measurement — and a picker that offered fewer options for one of them
/// is how the old Trends screen ended up with four series.
struct MetricPicker: View {
    let title: String
    let selected: MetricSpec?
    let clearable: Bool
    let onPick: (MetricSpec?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if clearable {
                        row(label: "Nothing", unit: "", marked: selected == nil) {
                            onPick(nil)
                        }
                    }

                    ForEach(MetricSpec.Group.allCases, id: \.self) { g in
                        SectionRule(text: g.rawValue).padding(.top, 22)
                        ForEach(Metrics.inGroup(g)) { m in
                            row(label: m.label, unit: m.unit, marked: selected?.id == m.id) {
                                onPick(m)
                            }
                        }
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .background(Theme.linen)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(
        label: String,
        unit: String,
        marked: Bool,
        tap: @escaping () -> Void
    ) -> some View {
        Button(action: tap) {
            HStack {
                Text(label)
                    .font(Theme.serif(18))
                    .foregroundStyle(marked ? Theme.amber : Theme.ink)
                Spacer()
                if !unit.isEmpty {
                    Text(unit).font(Theme.sans(10)).foregroundStyle(Theme.dust)
                }
                if marked { SelectionMark() }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }
}
