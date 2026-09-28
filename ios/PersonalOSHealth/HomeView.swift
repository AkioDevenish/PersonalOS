import SwiftUI

/// The landing page, laid out as a reading catalogue.
struct HomeView: View {
    @EnvironmentObject private var session: Session
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

                    if !library.archive.isEmpty {
                        section("Archive", seeAll: .articles(nil))
                            .flowIn(3)
                        row {
                            ForEach(library.archive) { article in
                                NavigationLink(value: Route.article(article)) {
                                    ContentCard(
                                        title: article.title,
                                        note: article.isLocked ? "Subscribers" : "\(article.minutes) min read",
                                        symbol: article.isLocked ? "lock" : article.symbol,
                                        tint: article.tint
                                    )
                                }
                                .buttonStyle(.pressRow)
                            }
                        }
                        .flowIn(3)
                    }

                    ForEach(Array(library.categories.enumerated()), id: \.element) { index, category in
                        section(category, seeAll: .articles(category))
                            .flowIn(3 + index)
                        row {
                            ForEach(library.filed(under: category)) { article in
                                NavigationLink(value: Route.article(article)) {
                                    ContentCard(
                                        title: article.title,
                                        note: article.isLocked ? "Subscribers" : "\(article.minutes) min read",
                                        symbol: article.isLocked ? "lock" : article.symbol,
                                        tint: article.tint
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
        .task { await library.refresh() }
        .refreshable { await library.refresh() }
    }

    // MARK: Search

    /// A large title with your face on the right, and a search field under it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Home")
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.text)
                Spacer()
                NavigationLink(value: Route.profile) {
                    Avatar(account: session.account, size: 32)
                }
                .buttonStyle(.press)
                .accessibilityLabel("Profile")
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.tertiaryText)
                    .accessibilityHidden(true)
                TextField("Search articles", text: $query)
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

    /// Articles matching the search.
    @ViewBuilder
    private var results: some View {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let articles = library.all.filter {
            [$0.title, $0.summary, $0.category].contains { $0.lowercased().contains(needle) }
        }

        VStack(alignment: .leading, spacing: 0) {
            if articles.isEmpty {
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
                                note: article.isLocked ? "Subscribers" : "\(article.minutes) min read",
                                symbol: article.isLocked ? "lock" : article.symbol,
                                tint: article.tint, raised: true
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
}
