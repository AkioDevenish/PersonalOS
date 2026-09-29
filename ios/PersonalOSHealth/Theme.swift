import SwiftUI

/// The design language.
enum Theme {
    // MARK: Colors

    /// The page, as a flat colour. Pages draw `gradient` instead; this is for text on dark buttons.
    static let background = adaptive(light: 0xEBE1CF, dark: 0x1E1A15)
    /// A card or field sitting on the page.
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x3A332C, alpha: 0.55)
    /// A card sitting on a surface.
    static let raised = adaptive(light: 0xFFFFFF, dark: 0x453D35, alpha: 0.78)
    /// Titles, figures, primary text.
    static let text = adaptive(light: 0x26211C, dark: 0xF4EFE6)
    static let secondaryText = adaptive(light: 0x6B6259, dark: 0xB8AFA4)
    /// Notes and captions.
    static let tertiaryText = adaptive(light: 0x9A9084, dark: 0x8A8177)
    /// Links, the selected tab, highlights.
    static let accent = adaptive(light: 0x8C6A4A, dark: 0xD2B48C)
    /// Something met or connected.
    static let positive = adaptive(light: 0x4E7F52, dark: 0x8CC48F)
    static let separator = adaptive(light: 0xFFFFFF, dark: 0xFFFFFF, alpha: 0.35)

    /// Bone to porcelain in light mode; a warm espresso in dark.
    static let gradient = LinearGradient(
        colors: [
            adaptive(light: 0xD9CAB0, dark: 0x14110E),
            adaptive(light: 0xE3D6C0, dark: 0x1B1713),
            adaptive(light: 0xEBE1CF, dark: 0x221D18),
            adaptive(light: 0xF2EBDF, dark: 0x28221C),
            adaptive(light: 0xF7F2E9, dark: 0x2E2720),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

extension View {
    /// The app's gradient behind a whole page.
    func appBackground() -> some View {
        background { Theme.gradient.ignoresSafeArea() }
    }
}

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
