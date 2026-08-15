import SwiftUI

/// The screen you open in the morning: date, briefing, the ledger.
struct HealthView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshot: HealthSnapshot?
    @State private var loadFailed = false
    @State private var appeared = false

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    /// The three figures a day is actually judged on.
    ///
    /// A grid of nineteen equal numbers is a table, and a table has no opinion.
    /// These three lead because they are what a person checks first — how you
    /// slept, how much you moved, and what your heart made of it — and they are
    /// set large enough to be read from a pocket rather than studied.
    private var lead: [MetricSpec] {
        ["sleep", "steps", "resting_hr"]
            .compactMap { Metrics.by(id: $0) }
            .filter { spec in snapshot.flatMap { spec.value($0) } != nil }
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

                // MARK: The day

                HStack(spacing: 10) {
                    Kicker(text: dateKicker, color: Theme.amber, size: 11)
                    if let mood = snapshot?.stateOfMindLabels, !mood.isEmpty {
                        Text(mood)
                            .font(Theme.sans(10))
                            .tracking(1.2)
                            .foregroundStyle(Theme.mid)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                    }
                }
                .padding(.top, 8)
                .flowIn(0)

                // The briefing's own headline is the page's headline. It used
                // to say "The day so far." over a summary that then said what
                // sort of day it was — two titles, one of them generic. The
                // page now leads with the sentence that actually knows
                // something: "A short night, steady heart."
                Text(briefing.headline)
                    .font(Theme.serif(38))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .flowIn(1)

                // MARK: The read

                NavigationLink(value: Route.briefing) {
                    VStack(alignment: .leading, spacing: 12) {
                        // More than the one line it used to show. Two
                        // paragraphs is the length at which the briefing reads
                        // as something written rather than a status field.
                        ForEach(Array(briefing.paragraphs.prefix(2).enumerated()), id: \.element) { _, p in
                            Text(p)
                                .font(Theme.serifBody(18))
                                .foregroundStyle(Theme.mid)
                                .lineSpacing(7)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let first = briefing.suggestions.first {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("I")
                                    .font(Theme.serif(15))
                                    .foregroundStyle(Theme.amber)
                                Text(first)
                                    .font(Theme.serifBody(16.5))
                                    .foregroundStyle(Theme.ink)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 2)
                        }

                        Text("READ THE FULL BRIEFING  →")
                            .font(Theme.sans(10, medium: true))
                            .tracking(1.8)
                            .foregroundStyle(Theme.amber)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressRow)
                .padding(.top, 20)
                .flowIn(2)

                // MARK: The three that matter

                if !lead.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(lead.enumerated()), id: \.element.id) { i, spec in
                            VStack(alignment: .leading, spacing: 7) {
                                Kicker(text: spec.label, size: 8.5)
                                    .lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(snapshot.flatMap { spec.display($0) } ?? "—")
                                        .font(Theme.serif(34))
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
                            .flowIn(3 + i)
                        }
                    }
                    .padding(.top, 34)
                }

                // MARK: Everything else recorded

                ForEach(Array(Metrics.populatedGroups(snapshot).enumerated()), id: \.element) { i, group in
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

                if snapshot != nil && Metrics.populatedGroups(snapshot).isEmpty {
                    Text("Nothing recorded yet today.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 26)
                }

                // MARK: Where to go next
                //
                // At the bottom, not between the briefing and the figures. It
                // was interrupting the read: three doors to other screens
                // stood between what today looks like and what today's numbers
                // are. Somewhere to go next belongs after you have read.

                SectionRule(text: "Go deeper")
                    .padding(.top, 46)
                    .flowIn(11)

                VStack(spacing: 0) {
                    consultRow("Records", "Any measurement over time — or two against each other", 12, .history)
                    consultRow("Nutrition", "What to eat next, from your own readings", 13, .nutrition)
                    consultRow("Specialists", "Read by an expert", 14, .specialists)
                }
                .padding(.top, 8)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
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

    /// A door to one of the engines, in the ledger's list idiom.
    ///
    /// The rows arrive on the same stagger as the metric grid — the screen
    /// writes itself down the page — and press in under the finger, which on a
    /// list with no fill is the only sign a tap landed before the push begins.
    private func consultRow(
        _ title: String,
        _ subtitle: String,
        _ index: Int,
        _ route: Route
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.serif(19))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(Theme.sans(10.5))
                        .foregroundStyle(Theme.dust)
                }
                Spacer()
                Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
        .flowIn(index)
    }

    private func load() async {
        do {
            try await health.requestAuthorization()
            snapshot = try await health.fetchTodaySnapshot()
        } catch {
            loadFailed = true
        }
        // Drives the glyph stagger. Set after the read so the icons animate in
        // alongside their numbers rather than over an empty grid.
        withAnimation(Theme.Motion.flow) { appeared = true }
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
