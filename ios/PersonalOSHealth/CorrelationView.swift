import SwiftUI
import Charts

/// The correlation engine: two metrics on one timeline.
///
/// Ported from the old dashboard, with one change worth stating — the series
/// are normalised to a shared 0–1 scale before plotting. Steps run to five
/// figures and resting heart rate to two; drawn on one axis the smaller series
/// would flatten into the baseline and look like nothing was happening. The
/// plates underneath keep the real numbers, and Pearson's r is computed on the
/// raw values, never the normalised ones.
struct CorrelationView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshots: [HealthSnapshot] = []
    @State private var days = 30
    @State private var a: MetricSpec = Metrics.by(id: "steps") ?? Metrics.all[0]
    @State private var b: MetricSpec = Metrics.by(id: "sleep") ?? Metrics.all[1]
    @State private var loading = true
    @State private var picking: Int? = nil

    private struct Pair { let date: Date; let a: Double; let b: Double }

    /// Only days where both metrics have a value — a correlation over gaps is
    /// not a correlation.
    private var pairs: [Pair] {
        snapshots.compactMap { s in
            guard let va = a.value(s), let vb = b.value(s) else { return nil }
            return Pair(date: s.recordedAt, a: va, b: vb)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Correlation", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("Does one follow\nthe other?")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 8)
                    .flowIn(1)

                pickers.padding(.top, 22).flowIn(2)
                rangePills.padding(.top, 16).flowIn(3)

                chart.padding(.top, 24).flowIn(4)

                if let r = pearson {
                    Plate {
                        VStack(alignment: .leading, spacing: 8) {
                            Kicker(text: "Pearson's r", size: 9)
                            Text(String(format: "%.2f", r))
                                .font(Theme.serif(34))
                                .foregroundStyle(Theme.ink)
                            Text(interpretation(r))
                                .font(Theme.serifBody(16))
                                .foregroundStyle(Theme.mid)
                                .lineSpacing(5)
                            Text("Over \(pairs.count) days with both readings. Association, not cause.")
                                .font(Theme.sans(10.5))
                                .foregroundStyle(Theme.dust)
                        }
                    }
                    .padding(.top, 22)
                    .flowIn(5)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .sheet(item: Binding(
            get: { picking.map { PickerTarget(slot: $0) } },
            set: { picking = $0?.slot }
        )) { target in
            metricPicker(for: target.slot)
        }
    }

    private struct PickerTarget: Identifiable { let slot: Int; var id: Int { slot } }

    private var pickers: some View {
        VStack(spacing: 0) {
            Rule()
            pickerRow(label: "First", metric: a, colour: Theme.ink) { picking = 0 }
            Rule()
            pickerRow(label: "Second", metric: b, colour: Theme.amber) { picking = 1 }
            Rule()
        }
    }

    private func pickerRow(label: String, metric: MetricSpec, colour: Color, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                Circle().fill(colour).frame(width: 8, height: 8)
                Kicker(text: label, size: 9)
                Spacer()
                Text(metric.label)
                    .font(Theme.serif(19))
                    .foregroundStyle(Theme.ink)
                Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }

    private func metricPicker(for slot: Int) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(MetricSpec.Group.allCases, id: \.self) { g in
                        SectionRule(text: g.rawValue).padding(.top, 22)
                        ForEach(Metrics.inGroup(g)) { m in
                            Button {
                                Haptics.select()
                                withAnimation(Theme.Motion.bouncy) {
                                    if slot == 0 { a = m } else { b = m }
                                }
                                picking = nil
                            } label: {
                                HStack {
                                    Text(m.label)
                                        .font(Theme.serif(18))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    if !m.unit.isEmpty {
                                        Text(m.unit).font(Theme.sans(10)).foregroundStyle(Theme.dust)
                                    }
                                }
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressRow)
                            Rule()
                        }
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .background(Theme.linen)
            .navigationTitle("Choose a metric")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var rangePills: some View {
        PillPicker(values: [14, 30, 90], selection: $days) { "\($0) days" }
            .onSelect { Task { await load() } }
    }

    /// Scales a series into 0–1 so two different magnitudes share an axis.
    private func normalise(_ values: [Double]) -> [Double] {
        guard let lo = values.min(), let hi = values.max(), hi > lo else {
            return values.map { _ in 0.5 }
        }
        return values.map { ($0 - lo) / (hi - lo) }
    }

    @ViewBuilder
    private var chart: some View {
        if loading {
            note("Reading your history…")
        } else if pairs.count < 3 {
            note("Not enough days where both were recorded.")
        } else {
            let na = normalise(pairs.map(\.a))
            let nb = normalise(pairs.map(\.b))
            Chart {
                ForEach(Array(pairs.enumerated()), id: \.offset) { i, p in
                    LineMark(x: .value("Day", p.date, unit: .day),
                             y: .value(a.label, na[i]),
                             series: .value("s", a.label))
                        .foregroundStyle(Theme.ink)
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", p.date, unit: .day),
                             y: .value(b.label, nb[i]),
                             series: .value("s", b.label))
                        .foregroundStyle(Theme.amber)
                        .interpolationMethod(.catmullRom)
                }
            }
            // The axis is a shared 0–1 scale and would only mislead.
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days > 20 ? 7 : 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(Theme.sans(9)).foregroundStyle(Theme.dust)
                }
            }
            .frame(height: 210)

            HStack(spacing: 13) {
                legendPlate(a, values: pairs.map(\.a), colour: Theme.ink)
                legendPlate(b, values: pairs.map(\.b), colour: Theme.amber)
            }
            .padding(.top, 16)
        }
    }

    private func legendPlate(_ m: MetricSpec, values: [Double], colour: Color) -> some View {
        let avg = values.reduce(0, +) / Double(max(values.count, 1))
        return Plate {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Circle().fill(colour).frame(width: 7, height: 7)
                    Kicker(text: m.label, size: 9)
                }
                Text(m.precision == 0 ? MetricSpec.grouped(avg) : String(format: "%.\(m.precision)f", avg))
                    .font(Theme.serif(24))
                    .foregroundStyle(Theme.ink)
                Text("avg \(m.unit)")
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
            }
        }
    }

    private func note(_ t: String) -> some View {
        Text(t)
            .font(Theme.sans(12))
            .foregroundStyle(Theme.dust)
            .frame(maxWidth: .infinity).frame(height: 210)
    }

    /// Pearson's r on the raw values.
    private var pearson: Double? {
        let xs = pairs.map(\.a), ys = pairs.map(\.b)
        guard xs.count >= 3 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var num = 0.0, dx = 0.0, dy = 0.0
        for i in 0..<xs.count {
            let a = xs[i] - mx, b = ys[i] - my
            num += a * b; dx += a * a; dy += b * b
        }
        guard dx > 0, dy > 0 else { return nil }
        return num / (dx.squareRoot() * dy.squareRoot())
    }

    private func interpretation(_ r: Double) -> String {
        let strength: String
        switch abs(r) {
        case ..<0.2: return "No meaningful relationship in this window."
        case ..<0.4: strength = "a weak"
        case ..<0.6: strength = "a moderate"
        case ..<0.8: strength = "a strong"
        default: strength = "a very strong"
        }
        return r > 0
            ? "There's \(strength) tendency for \(b.label.lowercased()) to rise with \(a.label.lowercased())."
            : "There's \(strength) tendency for \(b.label.lowercased()) to fall as \(a.label.lowercased()) rises."
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
