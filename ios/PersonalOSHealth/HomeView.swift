import SwiftUI

/// The landing page, laid out as a catalogue rather than a page of writing.
///
/// A large title, a search field, then sections that each carry a heading, an
/// optional way through, and one row of cards you can swipe along. Rows run to
/// the edge of the screen and let the next card show, which is the cue that
/// there is more to the side without having to say so.
///
/// Nothing here is a second copy of another screen. Explore is the way into
/// the five places that are not tabs; Today is the briefing and the goals; and
/// Your readings is what Apple Health has for today, each card a way into the
/// Health tab where the full picture lives.
struct HomeView: View {
    /// Sends you to another tab. The bar's selection lives in RootView, so
    /// the page asks rather than reaches.
    var go: (AppTab) -> Void

    @EnvironmentObject private var health: HealthKitManager
    @State private var snapshot: HealthSnapshot?
    @State private var healthLoading = true
    @State private var query = ""

    /// Worked out when the reading arrives rather than while the page draws:
    /// neither depends on anything but the snapshot.
    @State private var briefing = Briefing.compose(from: nil)
    @State private var goals: [Goals.Progress] = []

    private let margin: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Home")
                    .font(Theme.serif(38))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, margin)
                    .padding(.top, 12)
                    .flowIn(0)

                searchField
                    .padding(.horizontal, margin)
                    .padding(.top, 14)
                    .flowIn(0)

                if searching {
                    results
                        .padding(.top, 18)
                } else {
                    section("Explore")
                        .flowIn(1)
                    exploreRow
                        .flowIn(1)

                    section("Today", link: ("Briefing", { }), route: .briefing)
                        .flowIn(2)
                    todayRow
                        .flowIn(2)

                    section("Your readings", link: ("View All", { go(.health) }))
                        .flowIn(3)
                    readingsRow
                        .flowIn(3)
                }
            }
            .padding(.bottom, 24)
        }
        .compactsTabBar()
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: Search

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.tertiaryText)
            TextField("Search readings, experts or pages", text: $query)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.text)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if searching {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: Capsule())
    }

    /// Search finds the places you can go and the measurements you can read.
    /// Practitioners are searched on their own screen, where the directory is,
    /// rather than fetched here on every keystroke.
    @ViewBuilder
    private var results: some View {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let places = Self.places.filter {
            $0.title.lowercased().contains(needle) || $0.note.lowercased().contains(needle)
        }
        let metrics = Metrics.all.filter {
            $0.label.lowercased().contains(needle) || ($0.phrase?.lowercased().contains(needle) ?? false)
        }

        VStack(alignment: .leading, spacing: 0) {
            if places.isEmpty && metrics.isEmpty {
                Text("Nothing called “\(query)”.")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, margin)
                    .padding(.top, 12)
            }
            ForEach(places, id: \.route) { place in
                NavigationLink(value: place.route) {
                    resultRow(symbol: place.symbol, title: place.title, note: place.note)
                }
                .buttonStyle(.pressRow)
            }
            ForEach(metrics, id: \.id) { spec in
                Button {
                    go(.health)
                } label: {
                    resultRow(
                        symbol: spec.symbol,
                        title: spec.label,
                        note: snapshot.flatMap { spec.display($0) }.map { "\($0) \(spec.unit) today" }
                            ?? "Nothing recorded today"
                    )
                }
                .buttonStyle(.pressRow)
            }
        }
    }

    private func resultRow(symbol: String, title: String, note: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .environment(\.symbolVariants, .none)
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.sans(16, medium: true)).foregroundStyle(Theme.text)
                Text(note).font(Theme.sans(13)).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, margin)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: Sections

    /// A heading, and a way through when there is somewhere to go.
    @ViewBuilder
    private func section(
        _ title: String,
        link: (String, () -> Void)? = nil,
        route: Route? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.serif(24))
                .foregroundStyle(Theme.text)
            Spacer()
            if let link {
                if let route {
                    NavigationLink(value: route) { linkLabel(link.0) }
                        .buttonStyle(.plain)
                } else {
                    Button(action: link.1) { linkLabel(link.0) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, margin)
        .padding(.top, 30)
        .padding(.bottom, 12)
    }

    private func linkLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(15))
            .foregroundStyle(Theme.accent)
    }

    /// One row of cards that runs to the screen's edges, starting on the margin.
    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) { content() }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, margin, for: .scrollContent)
    }

    // MARK: Explore

    private struct Place {
        let route: Route
        let title: String
        let note: String
        let symbol: String
        /// Saturated mid-tones, dark enough for white type and light enough to
        /// hold their own on a black page, so one set serves both appearances.
        let colour: Color
    }

    private static let places: [Place] = [
        .init(route: .history, title: "Records", note: "Any measurement, over time",
              symbol: "chart.xyaxis.line", colour: Color(red: 0.31, green: 0.43, blue: 0.56)),
        .init(route: .nutrition, title: "Nutrition", note: "What to eat next",
              symbol: "leaf", colour: Color(red: 0.36, green: 0.50, blue: 0.33)),
        .init(route: .specialists, title: "Specialists", note: "Read on this phone",
              symbol: "sparkles", colour: Color(red: 0.62, green: 0.20, blue: 0.18)),
        .init(route: .professionals, title: "Practitioners", note: "Real people you can ask",
              symbol: "person.2", colour: Color(red: 0.25, green: 0.46, blue: 0.51)),
        .init(route: .cycle, title: "Cycle", note: "Kept on this phone only",
              symbol: "circle.dotted", colour: Color(red: 0.62, green: 0.34, blue: 0.45)),
    ]

    private var exploreRow: some View {
        row {
            ForEach(Self.places, id: \.route) { place in
                NavigationLink(value: place.route) {
                    ZStack(alignment: .topLeading) {
                        place.colour
                        Image(systemName: place.symbol)
                            .font(.system(size: 46, weight: .light))
                            .environment(\.symbolVariants, .none)
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 18)
                        Text(place.title)
                            .font(Theme.sans(13, medium: true))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    .frame(width: 118, height: 162)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.pressRow)
                .accessibilityLabel("\(place.title). \(place.note)")
            }
        }
    }

    // MARK: Today

    private var todayRow: some View {
        row {
            NavigationLink(value: Route.briefing) {
                todayCard {
                    dateBlock
                } title: {
                    healthLoading ? "Reading today…" : briefing.headline.replacingOccurrences(of: "\n", with: " ")
                } note: {
                    "Today's briefing"
                }
            }
            .buttonStyle(.pressRow)

            NavigationLink(value: Route.goals) {
                todayCard {
                    goalsBlock
                } title: {
                    goals.isEmpty ? "Set a goal" : "\(goals.filter(\.met).count) of \(goals.count) kept"
                } note: {
                    goals.isEmpty ? "Steps, sleep and the rest" : "Goals"
                }
            }
            .buttonStyle(.pressRow)
        }
    }

    private func todayCard<Leading: View>(
        @ViewBuilder leading: () -> Leading,
        title: () -> String,
        note: () -> String
    ) -> some View {
        HStack(spacing: 14) {
            leading()
            VStack(alignment: .leading, spacing: 3) {
                Text(title())
                    .font(Theme.sans(16, medium: true))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(note())
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Theme.accent.opacity(0.12), in: Circle())
        }
        .padding(12)
        .containerRelativeFrame(.horizontal) { width, _ in width - margin * 2 - 28 }
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.separator, lineWidth: 1)
        }
    }

    /// A calendar leaf for today: the month in a dark band, the day under it.
    private var dateBlock: some View {
        let now = Date()
        return VStack(spacing: 0) {
            Text(now.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(Theme.sans(10, medium: true))
                .tracking(1.2)
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Theme.text)
            Text(now.formatted(.dateTime.day()))
                .font(Theme.serif(26))
                .foregroundStyle(Theme.text)
                .padding(.top, 4)
            Text(now.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(Theme.sans(9))
                .foregroundStyle(Theme.secondaryText)
                .padding(.bottom, 6)
        }
        .frame(width: 64)
        .overlay {
            RoundedRectangle(cornerRadius: 4).stroke(Theme.separator, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .combine)
    }

    /// Goals as marks, one per goal, filled where the day met it.
    private var goalsBlock: some View {
        VStack(spacing: 5) {
            Image(systemName: "target")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.accent)
            HStack(spacing: 3) {
                ForEach(goals.prefix(6)) { g in
                    Capsule()
                        .fill(g.met ? Theme.positive : Theme.separator)
                        .frame(width: 6, height: 4)
                }
            }
        }
        .frame(width: 64, height: 76)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Your readings

    /// What Apple Health has for today, in the catalogue's order.
    private var readings: [MetricSpec] {
        guard let snapshot else { return [] }
        return Metrics.all.filter { $0.display(snapshot) != nil }
    }

    private var readingsRow: some View {
        row {
            if healthLoading {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface)
                        .frame(width: 150, height: 176)
                }
            } else if readings.isEmpty {
                Button { go(.health) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nothing recorded yet today")
                            .font(Theme.sans(15, medium: true))
                            .foregroundStyle(Theme.text)
                        Text("Readings from Apple Health appear here as the day goes on.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .containerRelativeFrame(.horizontal) { width, _ in width - margin * 2 }
                    .frame(height: 120, alignment: .topLeading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.pressRow)
            } else {
                ForEach(readings, id: \.id) { spec in
                    Button { go(.health) } label: {
                        readingCard(spec)
                    }
                    .buttonStyle(.pressRow)
                }
            }
        }
    }

    private func readingCard(_ spec: MetricSpec) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: spec.symbol)
                .font(.system(size: 20, weight: .light))
                .environment(\.symbolVariants, .none)
                .foregroundStyle(Theme.accent)
            Spacer()
            Text(snapshot.flatMap { spec.display($0) } ?? "–")
                .font(Theme.serif(34))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            if !spec.unit.isEmpty {
                Text(spec.unit)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(spec.label)
                .font(Theme.sans(13, medium: true))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.top, 8)
        }
        .padding(14)
        .frame(width: 150, height: 176, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Loading

    private func load() async {
        snapshot = try? await health.fetchTodaySnapshot()
        briefing = Briefing.compose(from: snapshot)
        goals = Goals.progress(on: snapshot)
        healthLoading = false
    }
}
