import SwiftUI

/// Something to read.
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
    /// Who wrote it, for articles from a practitioner.
    var author: String? = nil
    var credentials: String? = nil
    /// True for an archive article without a subscription: the title and summary are here, the
    /// words are not.
    var locked: Bool? = nil

    var isLocked: Bool { locked == true }

    var tint: Color { Article.tint(for: colour) }

    static func tint(for colour: String) -> Color {
        let value = UInt32(colour, radix: 16) ?? 0x3F7682
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum Articles {
    /// Read once from the bundle.
    static let bundled: [Article] = {
        guard let url = Bundle.main.url(forResource: "Articles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Article].self, from: data)
        else { return [] }
        return decoded
    }()

    /// What an author may choose from.
    static let categories = ["Your cycle", "Sleep & recovery", "Moving", "Eating", "Mind"]
    static let symbols = [
        "circle.dotted", "calendar.badge.clock", "heart", "moon.stars", "figure.walk",
        "figure.walk.motion", "leaf", "fork.knife", "brain.head.profile", "sparkles",
        "drop", "sun.max", "bed.double", "lungs", "stethoscope",
    ]
    static let colours = ["9E566F", "7A4E8C", "A0322E", "2F4A7A", "4E7A45", "3F6E7A", "8A6A2F", "5A5F6B"]
}

// MARK: - The card

/// One card, at the size of the ones in a content catalogue: a picture band on top and the words
/// beneath it, wide enough that a title reads as a title.
struct ContentCard: View {
    let title: String
    var note: String? = nil
    let symbol: String
    let tint: Color
    /// The card body sits one step off whatever it is laid on.
    var raised = false

    /// Measured off the reference screenshot's Most Read card, which is about 185 points wide at
    /// iPhone 15 Pro scale.
    static let width: CGFloat = 184
    static let pictureHeight: CGFloat = 98
    static let bodyHeight: CGFloat = 62

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [tint.opacity(0.22), tint.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .light))
                    .environment(\.symbolVariants, .none)
                    .foregroundStyle(tint)
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
        }
        .frame(width: Self.width)
        .background(raised ? Theme.raised : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reading

struct ArticleView: View {
    let article: Article

    var body: some View {
        ScrollView {
            ArticleContent(article: article)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The article itself, without a scroll view around it, so the reviewer's screen can show exactly
/// what readers will see inside its own page.
struct ArticleContent: View {
    let article: Article

    var body: some View {
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

            if let author = article.author {
                Text([author, article.credentials].compactMap { $0 }.joined(separator: ", "))
                    .font(Theme.sans(14, medium: true))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 8)
            }

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

            Text("This isn't medical advice. If you're worried, talk to a nutritionist.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 30)
        }
    }
}

/// Every article, or every article in one category, as a list.
struct ArticleListView: View {
    let category: String?
    @ObservedObject private var library = ArticleLibrary.shared

    private var articles: [Article] {
        category.map { library.filed(under: $0) } ?? library.all
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
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}
