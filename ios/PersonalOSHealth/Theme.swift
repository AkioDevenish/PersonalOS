import SwiftUI

/// The ledger design language, from the Figma file "Personal OS — iOS App".
///
/// One vocabulary for every screen: linen ground, ink for anything that
/// speaks, tracked Jost caps for labels, amber only as punctuation. Values
/// mirror the web tokens so the brand is one thing everywhere.
enum Theme {
    // MARK: Colors
    static let linen = Color(red: 0.949, green: 0.929, blue: 0.890)   // #F2EDE3
    static let warm  = Color(red: 0.976, green: 0.965, blue: 0.941)   // #F9F6F0
    static let ink   = Color(red: 0.157, green: 0.125, blue: 0.059)   // #28200F
    static let mid   = Color(red: 0.431, green: 0.365, blue: 0.271)   // #6E5D45
    static let dust  = Color(red: 0.659, green: 0.584, blue: 0.494)   // #A8957E
    static let amber = Color(red: 0.722, green: 0.518, blue: 0.353)   // #B8845A
    static let sage  = Color(red: 0.490, green: 0.576, blue: 0.478)   // #7D937A
    static let hairline = Color(red: 0.157, green: 0.125, blue: 0.059).opacity(0.16)

    // MARK: Fonts
    // PostScript names verified from the bundled TTFs — the fontsource
    // statics are instanced from the Light master, hence the odd family name.
    static func serif(_ size: CGFloat) -> Font {
        .custom("CormorantGaramondLight-Medium", size: size)
    }
    static func serifBody(_ size: CGFloat) -> Font {
        .custom("CormorantGaramondLight-Regular", size: size)
    }
    static func serifItalic(_ size: CGFloat) -> Font {
        .custom("CormorantGaramondLight-MediumItalic", size: size)
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
    var color: Color = Theme.dust
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
        Rectangle().fill(Theme.hairline).frame(height: 1)
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
            .foregroundStyle(Theme.dust)
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
/// `Theme.warm` survives for type on ink, where it is a foreground colour.
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
