import SwiftUI

struct BriefingView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var period: BriefingPeriod = .daily
    /// The window's completed days. For a daily briefing this is still the
    /// trailing week, because "8,431 steps" means nothing without knowing
    /// whether that is a lot for you.
    @State private var snapshots: [HealthSnapshot] = []
    @State private var today: HealthSnapshot?
    @State private var loading = true

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var kicker: String {
        period == .daily ? "\(period.label) · \(dateLine)" : "\(period.label) · \(period.window)"
    }

    /// Every metric with a reading, as a paragraph per group. The composing
    /// lives in Briefing beside the rest of the prose.
    private var breakdown: [(group: MetricSpec.Group, lines: [String])] {
        Briefing.breakdown(period: period, today: today, history: snapshots)
    }

    var body: some View {
        let b = Briefing.compose(period: period, snapshots: period == .daily ? [today].compactMap { $0 } : snapshots)
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
                    Text(
                        emphasising: p,
                        base: Theme.serifBody(18),
                        strong: Theme.serif(20),
                        baseColor: Theme.mid,
                        strongColor: Theme.ink
                    )
                    .lineSpacing(7)
                    .padding(.top, 16)
                    .flowIn(3 + i)
                }

                // The evidence, after the read and before what to do about it.
                ForEach(Array(breakdown.enumerated()), id: \.element.group) { i, section in
                    SectionRule(text: section.group.rawValue)
                        .padding(.top, i == 0 ? 30 : 26)
                        .flowIn(3 + b.paragraphs.count + i)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(section.lines, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("·")
                                    .font(Theme.serif(17))
                                    .foregroundStyle(Theme.amber)
                                Text(
                                    emphasising: line,
                                    base: Theme.serifBody(16.5),
                                    strong: Theme.serif(18.5)
                                )
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 14)
                    .flowIn(3 + b.paragraphs.count + i)
                }

                if breakdown.isEmpty && !loading {
                    Text("Nothing measurable recorded in this window.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 26)
                }

                Ornament()
                    .padding(.vertical, 26)
                    .flowIn(4 + b.paragraphs.count + breakdown.count)

                Kicker(text: b.suggestions.count == 1 && b.suggestions[0].hasPrefix("No goals")
                       ? "Goals"
                       : period.spend)
                    .flowIn(5 + b.paragraphs.count + breakdown.count)

                ForEach(Array(b.suggestions.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(["I", "II", "III", "IV"][min(i, 3)])
                            .font(Theme.serif(17))
                            .foregroundStyle(Theme.amber)
                            .frame(width: 22, alignment: .leading)
                        Text(emphasising: s)
                            .lineSpacing(5)
                    }
                    .padding(.top, 14)
                    .flowIn(6 + b.paragraphs.count + breakdown.count + i)
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
            // Both, always. A day reads from today's live snapshot rather than
            // yesterday's stored one — the morning briefing is about a day in
            // progress, and the history read only holds completed days — but
            // the breakdown needs the days behind it either way, to say
            // whether today's figure is a lot for you or not.
            today = try await health.fetchTodaySnapshot()
            snapshots = try await health.fetchHistoricalSnapshots(
                days: max(period.days, 7)
            )
        } catch {
            today = nil
            snapshots = []
        }
    }
}
