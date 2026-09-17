import SwiftUI
import ClerkKit

/// The landing page, laid out as a reading catalogue.
///
/// A search at the top, the most read articles on a band of their own with a
/// page indicator beneath, the places you can go, and then a shelf per
/// subject. Every row runs to the edge of the screen and lets the next card
/// show, which is the cue that there is more to the side.
///
/// Cards are one size throughout — a picture band over the title, wide enough
/// that a title reads as one — so Explore and the articles look like parts of
/// the same page rather than two designs next to each other.
struct HomeView: View {
    /// Sends you to another tab. The bar's selection lives in RootView, so
    /// the page asks rather than reaches.
    var go: (AppTab) -> Void

    @EnvironmentObject private var health: HealthKitManager
    @Environment(Clerk.self) private var clerk
    @State private var snapshot: HealthSnapshot?
    @State private var query = ""
    @ObservedObject private var library = ArticleLibrary.shared
    /// Which most-read card is centred, for the page indicator.
    @State private var featured: String?
    @FocusState private var searchFocused: Bool

    private let margin: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if searching {
                    results
                        .padding(.top, 8)
                } else {
                    mostRead
                        .flowIn(1)

                    section("Explore")
                        .flowIn(2)
                    row {
                        ForEach(Self.places, id: \.route) { place in
                            NavigationLink(value: place.route) {
                                ContentCard(
                                    title: place.title, note: place.note,
                                    symbol: place.symbol, tint: place.colour
                                )
                            }
                            .buttonStyle(.pressRow)
                        }
                    }
                    .flowIn(2)

                    ForEach(Array(library.categories.enumerated()), id: \.element) { index, category in
                        section(category, seeAll: .articles(category))
                            .flowIn(3 + index)
                        row {
                            ForEach(library.filed(under: category)) { article in
                                NavigationLink(value: Route.article(article)) {
                                    ContentCard(
                                        title: article.title,
                                        note: "\(article.minutes) min read",
                                        symbol: article.symbol, tint: article.tint
                                    )
                                }
                                .buttonStyle(.pressRow)
                            }
                        }
                        .flowIn(3 + index)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .compactsTabBar()
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
        .task { snapshot = try? await health.fetchTodaySnapshot() }
        .task { await library.refresh() }
        .refreshable { await library.refresh() }
    }

    // MARK: Search

    /// A large title with your face on the right, and a search field under it.
    ///
    /// The face is the way to Profile from the top of the page, where people
    /// look for it, as well as from the bar.
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Home")
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.text)
                Spacer()
                NavigationLink(value: Route.profile) {
                    Avatar(user: clerk.user, size: 32)
                }
                .buttonStyle(.press)
                .accessibilityLabel("Profile")
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.tertiaryText)
                    .accessibilityHidden(true)
                TextField("Search articles, readings or pages", text: $query)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.text)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if searching {
                    Button { query = "" } label: {
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
            .contentShape(Capsule())
            .onTapGesture { searchFocused = true }
        }
        .padding(.horizontal, margin)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Articles first, because that is what the field says it finds, then the
    /// places and the measurements.
    @ViewBuilder
    private var results: some View {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let articles = library.all.filter {
            [$0.title, $0.summary, $0.category].contains { $0.lowercased().contains(needle) }
        }
        let places = Self.places.filter {
            $0.title.lowercased().contains(needle) || $0.note.lowercased().contains(needle)
        }
        let metrics = Metrics.all.filter {
            $0.label.lowercased().contains(needle) || ($0.phrase?.lowercased().contains(needle) ?? false)
        }

        VStack(alignment: .leading, spacing: 0) {
            if articles.isEmpty && places.isEmpty && metrics.isEmpty {
                Text("Nothing matches “\(query)”.")
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, margin)
            }
            ForEach(articles) { article in
                NavigationLink(value: Route.article(article)) {
                    resultRow(symbol: article.symbol, title: article.title,
                              note: "\(article.category) · \(article.minutes) min read")
                }
                .buttonStyle(.pressRow)
            }
            ForEach(places, id: \.route) { place in
                NavigationLink(value: place.route) {
                    resultRow(symbol: place.symbol, title: place.title, note: place.note)
                }
                .buttonStyle(.pressRow)
            }
            ForEach(metrics, id: \.id) { spec in
                Button { go(.health) } label: {
                    resultRow(
                        symbol: spec.symbol, title: spec.label,
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

    // MARK: Daily News

    /// On a band of its own, cards snapping one at a time, with a dot per card.
    private var mostRead: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daily News")
                .font(Theme.sans(19, medium: true))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, margin)
                .padding(.bottom, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(library.all) { article in
                        NavigationLink(value: Route.article(article)) {
                            ContentCard(
                                title: article.title,
                                note: "\(article.minutes) min read",
                                symbol: article.symbol, tint: article.tint, raised: true
                            )
                        }
                        .buttonStyle(.pressRow)
                        .id(article.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $featured, anchor: .leading)

            HStack(spacing: 8) {
                ForEach(library.all) { article in
                    Circle()
                        .fill((featured ?? library.all.first?.id) == article.id
                              ? Theme.text : Theme.tertiaryText.opacity(0.5))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 22)
        .background(Theme.surface)
    }

    // MARK: Sections

    private func section(_ title: String, seeAll route: Route? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.sans(19, medium: true))
                .foregroundStyle(Theme.text)
            Spacer()
            if let route {
                NavigationLink(value: route) {
                    HStack(spacing: 4) {
                        Text("See all")
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    }
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, margin)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) { content() }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, margin, for: .scrollContent)
    }

    // MARK: Places

    private struct Place {
        let route: Route
        let title: String
        let note: String
        let symbol: String
        /// Saturated mid-tones that carry white type and hold their own on a
        /// black page, so one set serves both appearances.
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
}
