import SwiftUI

/// The design language.
///
/// Colours follow the phone. Every token below resolves differently in light
/// and dark appearance, so the app turns dark when the system does without a
/// single screen having to ask which it is. The neutrals are Apple's own
/// semantic colours rather than hand-picked greys, because those are the ones
/// tuned for contrast in both appearances and for Increase Contrast too.
///
/// The names describe a job rather than a colour. They used to be linen, warm,
/// ink and amber, which were accurate while the app was beige and would have
/// been wrong in every file the moment it stopped being.
enum Theme {
    // MARK: Colors

    /// The page. White in light, black in dark.
    static let background = Color(uiColor: .systemBackground)
    /// A card or field sitting on the page, one step off it.
    static let surface = Color(uiColor: .secondarySystemBackground)
    /// Anything that speaks: titles, figures, primary text.
    static let text = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    /// Notes and captions. Between secondary and tertiary label, because the
    /// system's tertiary is too faint to carry a sentence someone should read.
    static let tertiaryText = adaptive(light: 0x3C3C43, dark: 0xEBEBF5, alpha: 0.5)
    /// The one colour, used as punctuation: links, the selected tab, today.
    /// A muted teal, lifted in dark so it keeps its contrast on black.
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
    //
    // EB Garamond, as two variable files carrying five real weights each
    // (400 to 800 on the weight axis) plus their italics. PostScript names
    // below were read back out of the bundled files with CoreText rather than
    // guessed from the filenames.
    //
    // This replaced Cormorant Garamond, whose static cuts were both instanced
    // from the Light master: asking for Medium silently returned Light, so
    // emphasis had to be faked with a size step and a colour. These are
    // genuinely different weights, so bold can be bold again.
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
///
/// The specialist screen builds its own button label out of two things you
/// picked, and read "Ask the endocrinologist for a hourly reading". The vowel
/// test alone doesn't get there: it is the sound that takes "an", not the
/// letter, so the silent h in "hourly" needs saying out loud.
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
///
/// Nearly gone. This was the design's structural mark and it ended up drawn
/// under every row, every figure and both sides of every heading — a home
/// screen with nineteen metrics had twenty-five lines on it, and a page ruled
/// that heavily reads as a form to fill in rather than a page to read. What is
/// left is one line above the tab bar, where it separates a fixed control from
/// content that scrolls underneath it, and the flourish on sign-in.
///
/// Everything else is held apart by space now. Space is the same instruction
/// as a line and costs no ink.
struct Rule: View {
    var body: some View {
        Rectangle().fill(Theme.separator).frame(height: 1)
    }
}

/// A section heading.
///
/// Was ── LABEL ──, flanked by rules. Tracked caps in dust on a linen ground
/// are already the quietest thing on the screen; they did not need underlining
/// from both sides to be read as a heading. The space above a heading is what
/// says a new section has started.
struct SectionRule: View {
    let text: String
    var body: some View {
        Kicker(text: text)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The closing ornament, now just the mark.
struct Ornament: View {
    var body: some View {
        Text("❧")
            .font(Theme.serif(15))
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// A block of content on the ground.
///
/// This was a warm-white card with a border. On linen that read as paper
/// floating on paper — a lighter rectangle behind every figure — and once
/// several appeared on a screen it became a grid of tiles rather than a page
/// of writing. The fill and the border went, leaving a rule under the content;
/// that rule has now gone too, along with the rest of them. A block of writing
/// with air around it is already a block.
///
/// Changed here rather than at each call site so every screen moves together.
/// `Theme.surface` survives for type on ink, where it is a foreground colour.
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
