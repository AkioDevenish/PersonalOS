import SwiftUI

/// The design language.
enum Theme {
    // MARK: Colors

    /// The page.
    static let background = Color(uiColor: .systemBackground)
    /// A card or field sitting on the page, one step off it.
    static let surface = Color(uiColor: .secondarySystemBackground)
    /// A card sitting on a surface: white on light grey, and in dark a step lighter again, the way
    /// content cards read on a banded section.
    static let raised = Color(uiColor: .tertiarySystemBackground)
    /// Anything that speaks: titles, figures, primary text.
    static let text = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    /// Notes and captions.
    static let tertiaryText = adaptive(light: 0x3C3C43, dark: 0xEBEBF5, alpha: 0.5)
    /// The one colour, used as punctuation: links, the selected tab, today.
    static let accent = adaptive(light: 0x3F7682, dark: 0x79B4C0)
    /// Something met or connected.
    static let positive = adaptive(light: 0x4E7F52, dark: 0x8CC48F)
    static let separator = Color(uiColor: .separator)

    private static func adaptive(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        func make(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha
            )
        }
        let lightColor = make(light), darkColor = make(dark)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor })
    }

    // MARK: Fonts
    // EB Garamond, as two variable files carrying five real weights each (400 to 800 on the weight
    // axis) plus their italics.
    static func serif(_ size: CGFloat) -> Font {
        .custom("EBGaramond-Medium", size: size)
    }
    static func serifBody(_ size: CGFloat) -> Font {
        .custom("EBGaramond-Regular", size: size)
    }
    static func serifItalic(_ size: CGFloat) -> Font {
        .custom("EBGaramond-MediumItalic", size: size)
    }
    static func sans(_ size: CGFloat, medium: Bool = false) -> Font {
        .custom(medium ? "Jost-Medium" : "Jost-Regular", size: size)
    }
}

// MARK: - Shared components

/// "a" or "an", for a word the app doesn't know in advance.
func indefiniteArticle(for word: String) -> String {
    let w = word.lowercased()
    let silentH = ["hour", "honest", "heir", "honour", "honor"]
    if silentH.contains(where: w.hasPrefix) { return "an" }
    guard let first = w.first else { return "a" }
    return "aeiou".contains(first) ? "an" : "a"
}

/// Tracked uppercase label — the design's only sans voice.
struct Kicker: View {
    let text: String
    var color: Color = Theme.tertiaryText
    var size: CGFloat = 10

    var body: some View {
        Text(text.uppercased())
            .font(Theme.sans(size, medium: false))
            .tracking(2.5)
            .foregroundStyle(color)
    }
}

/// 1px rule.
struct Rule: View {
    var body: some View {
        Rectangle().fill(Theme.separator).frame(height: 1)
    }
}

/// A section heading.
struct SectionRule: View {
    let text: String
    var body: some View {
        Kicker(text: text)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A block of content on the ground.
struct Plate<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}
