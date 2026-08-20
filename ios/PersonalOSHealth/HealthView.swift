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

                // MARK: The day

                Kicker(text: dateKicker, color: Theme.amber, size: 11)
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
                    .padding(.top, 16)
                    .flowIn(1)

                // A tracked-caps chip in an outlined capsule was the only
                // bordered object left on the page, and it made "excited and
                // grateful" look like a build tag. Someone's state of mind is
                // the softest thing the app knows: it belongs in the italic,
                // under the headline, with nothing drawn around it.
                if let mood = snapshot?.stateOfMindLabels, !mood.isEmpty {
                    Text(mood.lowercased() + ".")
                        .font(Theme.serifItalic(19))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 10)
                        .flowIn(1)
                }

                // MARK: The read

                NavigationLink(value: Route.briefing) {
                    VStack(alignment: .leading, spacing: 16) {
                        // More than the one line it used to show. Two
                        // paragraphs is the length at which the briefing reads
                        // as something written rather than a status field.
                        ForEach(Array(briefing.paragraphs.prefix(2).enumerated()), id: \.element) { _, p in
                            Text(
                                emphasising: p,
                                base: Theme.serifBody(18),
                                strong: Theme.serif(20)
                            )
                            .lineSpacing(7)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        if let first = briefing.suggestions.first {
                            VStack(alignment: .leading, spacing: 8) {
                                Kicker(text: "Still owing", size: 9)
                                Text(
                                    emphasising: first,
                                    base: Theme.serifBody(16.5),
                                    strong: Theme.serif(18.5)
                                )
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 14)
                        }

                        Text("READ THE FULL BRIEFING  →")
                            .font(Theme.sans(10, medium: true))
                            .tracking(1.8)
                            .foregroundStyle(Theme.amber)
                            .padding(.top, 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressRow)
                .padding(.top, 30)
                .flowIn(2)

                // MARK: The three that matter

                if !lead.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(lead.enumerated()), id: \.element.id) { i, spec in
                            VStack(alignment: .leading, spacing: 7) {
                                Kicker(text: spec.label, size: 8.5)
                                    .lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(snapshot.flatMap { spec.display($0) } ?? "·")
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
                    .padding(.top, 42)
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

                if snapshot != nil && shownGroups.isEmpty {
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
                    consultRow("Records", "Any measurement over time, or two against each other", 12, .history)
                    consultRow("Nutrition", "What to eat next, from your own readings", 13, .nutrition)
                    consultRow("Specialists", "Read by an expert", 14, .specialists)
                    consultRow("Goals", goalsSubtitle, 15, .goals)
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

    /// Says where the day stands against them, so the row is worth something
    /// before it is tapped.
    private var goalsSubtitle: String {
        let progress = Goals.progress(on: snapshot)
        guard !progress.isEmpty else { return "Set what you're aiming at" }
        let met = progress.filter(\.met).count
        return met == progress.count
            ? "All \(progress.count) met today"
            : "\(met) of \(progress.count) met today"
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
