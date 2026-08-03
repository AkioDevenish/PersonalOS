import SwiftUI
import Charts

/// The History tab: trends drawn from HealthKit on the device.
///
/// Deliberately reads HealthKit directly rather than the server. The charts
/// are then honest about what the phone actually holds, work with no network,
/// and don't wait on a sync having happened.
struct TrendsView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshots: [HealthSnapshot] = []
    @State private var days = 30
    @State private var loading = true

    /// Which series the chart is showing. Each knows how to pull its own value
    /// out of a snapshot, so adding one is a single case.
    enum Series: String, CaseIterable, Identifiable {
        case steps = "Steps"
        case sleep = "Sleep"
        case restingHR = "Resting HR"
        case energy = "Active energy"

        var id: String { rawValue }

        var unit: String {
            switch self {
            case .steps: return ""
            case .sleep: return "hrs"
            case .restingHR: return "bpm"
            case .energy: return "kcal"
            }
        }

        func value(_ s: HealthSnapshot) -> Double? {
            switch self {
            case .steps: return s.steps
            case .sleep: return (s.totalSleepHours ?? 0) > 0 ? s.totalSleepHours : nil
            case .restingHR: return s.restingHeartRate
            case .energy: return s.activeEnergyBurned
            }
        }

        /// Steps and energy accumulate; a bar reads as a total. Sleep and heart
        /// rate are levels, and a line reads as a trend.
        var isBar: Bool { self == .steps || self == .energy }
    }

    @State private var series: Series = .steps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "History", color: Theme.amber, size: 11)
                    .padding(.top, 8)

                Text("The ledger's past.")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                rangePicker.padding(.top, 20)

                SectionRule(text: series.rawValue).padding(.top, 26)

                chart.padding(.top, 20)

                summary.padding(.top, 22)

                SectionRule(text: "Show").padding(.top, 34)
                seriesPicker.padding(.top, 16)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
    }

    private var points: [(date: Date, value: Double)] {
        snapshots.compactMap { s in
            guard let v = series.value(s) else { return nil }
            return (s.recordedAt, v)
        }
    }

    @ViewBuilder
    private var chart: some View {
        if loading {
            placeholder("Reading your history…")
        } else if points.isEmpty {
            placeholder("No \(series.rawValue.lowercased()) recorded in this window.")
        } else {
            Chart {
                ForEach(points, id: \.date) { p in
                    if series.isBar {
                        BarMark(
                            x: .value("Day", p.date, unit: .day),
                            y: .value(series.rawValue, p.value)
                        )
                        .foregroundStyle(Theme.amber.opacity(0.75))
                    } else {
                        LineMark(
                            x: .value("Day", p.date, unit: .day),
                            y: .value(series.rawValue, p.value)
                        )
                        .foregroundStyle(Theme.ink)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Day", p.date, unit: .day),
                            y: .value(series.rawValue, p.value)
                        )
                        .foregroundStyle(Theme.amber)
                        .symbolSize(18)
                    }
                }

                if let avg = average {
                    RuleMark(y: .value("Average", avg))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Theme.dust)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel().font(Theme.sans(9)).foregroundStyle(Theme.dust)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days > 14 ? 7 : 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(Theme.sans(9))
                        .foregroundStyle(Theme.dust)
                }
            }
            .frame(height: 220)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(12))
            .foregroundStyle(Theme.dust)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
    }

    private var average: Double? {
        let vals = points.map(\.value)
        return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
    }

    private var summary: some View {
        HStack(spacing: 13) {
            statPlate("Average", average)
            statPlate("Best", points.map(\.value).max())
        }
    }

    private func statPlate(_ label: String, _ value: Double?) -> some View {
        Plate {
            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: label, size: 9)
                Text(value.map { format($0) } ?? "—")
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.ink)
                if !series.unit.isEmpty {
                    Text(series.unit)
                        .font(Theme.sans(10))
                        .foregroundStyle(Theme.dust)
                }
            }
        }
    }

    private func format(_ v: Double) -> String {
        switch series {
        case .steps, .energy: return TodayView.grouped(v)
        case .sleep: return String(format: "%.1f", v)
        case .restingHR: return String(Int(v.rounded()))
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach([7, 30, 90], id: \.self) { d in
                Button {
                    days = d
                    Task { await load() }
                } label: {
                    Text("\(d) DAYS")
                        .font(Theme.sans(10, medium: days == d))
                        .tracking(1.5)
                        .foregroundStyle(days == d ? Theme.warm : Theme.mid)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(days == d ? Theme.ink : .clear)
                        .overlay(Capsule().stroke(days == d ? .clear : Theme.hairline, lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var seriesPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Series.allCases) { s in
                Button { series = s } label: {
                    Text(s.rawValue)
                        .font(Theme.serif(17))
                        .foregroundStyle(series == s ? Theme.amber : Theme.mid)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(series == s ? Theme.amber : Theme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
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
