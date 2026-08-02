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

/// 1px rule, the ledger's line.
struct Rule: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// ── LABEL ── section heading.
struct SectionRule: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Rule()
            Kicker(text: text)
                .fixedSize()
            Rule()
        }
    }
}

/// ── ❧ ── closing ornament.
struct Ornament: View {
    var body: some View {
        HStack(spacing: 12) {
            Rule()
            Text("❧")
                .font(Theme.serif(14))
                .foregroundStyle(Theme.mid)
            Rule()
        }
    }
}

/// Warm-white plate with a hairline — the card of the system.
struct Plate<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.warm)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
