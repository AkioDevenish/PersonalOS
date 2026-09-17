import SwiftUI

/// Something to read.
///
/// Bundled with the app as `Articles.json` for now. That is a choice about
/// where the words live, not about the screens: moving them into Convex so
/// they can be edited without shipping a build changes `Articles.all` and
/// nothing that draws them.
struct Article: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let category: String
    let minutes: Int
    let symbol: String
    /// The card's colour, as six hex digits.
    let colour: String
    let summary: String
    let body: [String]

    var tint: Color {
        let value = UInt32(colour, radix: 16) ?? 0x3F7682
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum Articles {
    /// Read once from the bundle. A file that fails to decode is a build
    /// mistake, so it shows as an empty shelf rather than a crash.
    static let all: [Article] = {
        guard let url = Bundle.main.url(forResource: "Articles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Article].self, from: data)
        else { return [] }
        return decoded
    }()

    /// Categories in the order their first article appears.
    static var categories: [String] {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }
    }

    static func filed(under category: String) -> [Article] {
        all.filter { $0.category == category }
    }
}

// MARK: - The card

/// One card, at the size of the ones in a content catalogue: a picture band on
/// top and the words beneath it, wide enough that a title reads as a title.
///
/// Shared by Explore and the articles so the page has one shape of card
/// rather than two that nearly match.
struct ContentCard: View {
    let title: String
    var note: String? = nil
    let symbol: String
    let tint: Color
    /// The card body sits one step off whatever it is laid on. On the banded
    /// section that is the raised colour; on the plain page it is the surface.
    var raised = false

    /// Measured off the reference screenshot's Most Read card, which is
    /// about 185 points wide at iPhone 15 Pro scale. The first cut was a
    /// quarter bigger again and read as posters rather than a shelf.
    static let width: CGFloat = 184
    static let pictureHeight: CGFloat = 98
    static let bodyHeight: CGFloat = 62

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                tint
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .light))
                    .environment(\.symbolVariants, .none)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(height: Self.pictureHeight)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.sans(14, medium: true))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let note {
                    Text(note)
                        .font(Theme.sans(11.5))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(height: Self.bodyHeight)
            .background(raised ? Theme.raised : Theme.surface)
        }
        .frame(width: Self.width)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reading

struct ArticleView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    article.tint
                    Image(systemName: article.symbol)
                        .font(.system(size: 72, weight: .light))
                        .environment(\.symbolVariants, .none)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)

                Text(article.category.uppercased())
                    .font(Theme.sans(11, medium: true))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 22)

                Text(article.title)
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Label("\(article.minutes) min read", systemImage: "clock")
                    .font(Theme.sans(12.5))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 8)

                ForEach(Array(article.body.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(Theme.serifBody(18))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                }

                Text("General information, not medical advice. If something worries you, ask a practitioner.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .compactsTabBar()
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Every article, or every article in one category, as a list.
struct ArticleListView: View {
    let category: String?

    private var articles: [Article] {
        category.map { Articles.filed(under: $0) } ?? Articles.all
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(category ?? "Articles")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ForEach(articles) { article in
                    NavigationLink(value: Route.article(article)) {
                        HStack(spacing: 14) {
                            ZStack {
                                article.tint
                                Image(systemName: article.symbol)
                                    .font(.system(size: 24, weight: .light))
                                    .environment(\.symbolVariants, .none)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(Theme.sans(16, medium: true))
                                    .foregroundStyle(Theme.text)
                                    .multilineTextAlignment(.leading)
                                Text(article.summary)
                                    .font(Theme.sans(13))
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressRow)
                }
            }
            .padding(.bottom, 24)
        }
        .compactsTabBar()
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}
