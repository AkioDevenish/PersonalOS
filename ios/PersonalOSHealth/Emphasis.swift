import SwiftUI

/// Setting the measurements and the figures apart from the sentence around them.
///
/// The briefing is prose, and prose is the right form for it: "You slept 7h 13m
/// a night across 14 recorded nights" says something a table cannot. But nobody
/// reads a page of it word by word at eight in the morning. They look for the
/// name of a thing and the number beside it, and in flat body text those are
/// exactly as prominent as "across" and "a night".
///
/// So the two things a reader is hunting for are set in the stronger face: the
/// measurement's name, and every figure. Emphasis here is the Medium cut in
/// ink against the Regular cut in mid, which is what this design has instead of
/// bold — a heavier weight of the same serif, not a different voice.
///
/// Done by reading the sentence rather than by marking it up at the source. The
/// composer stays a producer of plain English, which keeps it testable on a
/// Mac and means nothing has to remember to close a tag.
enum Emphasis {

    /// Units, longest first, so "km/h" is never matched as "km".
    private static let units = [
        "mg/dL", "km/h", "kcal", "m/s", "bpm", "hrs", "min", "IU", "km", "kg", "g", "m", "%",
    ]

    /// A duration, a figure with thousands separators, or a bare number.
    private static let figures = try! NSRegularExpression(
        pattern: #"\d+h\s\d+m|\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?"#
    )

    /// Every name a metric goes by, longest first so "walking speed" wins over
    /// the "walking" inside it.
    private static let names: [String] = {
        var all = Set<String>()
        for spec in Metrics.all {
            all.insert(spec.label)
            if let phrase = spec.phrase { all.insert(phrase) }
        }
        return all.sorted { $0.count > $1.count }
    }()

    static func render(
        _ text: String,
        base: Font,
        strong: Font,
        baseColor: Color,
        strongColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        var cursor = text.startIndex

        for range in strongRanges(in: text) {
            if cursor < range.lowerBound {
                result += run(String(text[cursor..<range.lowerBound]), base, baseColor)
            }
            result += run(String(text[range]), strong, strongColor)
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            result += run(String(text[cursor...]), base, baseColor)
        }
        return result
    }

    private static func run(_ s: String, _ font: Font, _ colour: Color) -> AttributedString {
        var part = AttributedString(s)
        part.font = font
        part.foregroundColor = colour
        return part
    }

    /// The spans worth setting apart, in order and never overlapping.
    private static func strongRanges(in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)

        // Figures, each carrying its unit along with it: "118 mg/dL" is one
        // thing to the eye, and emphasising the number while leaving the unit
        // in the body face looks like a mistake rather than a decision.
        for match in figures.matches(in: text, range: whole) {
            var r = match.range
            for unit in units {
                let after = r.location + r.length
                for gap in [1, 0] where after + gap + unit.count <= ns.length {
                    let candidate = NSRange(location: after, length: gap + unit.count)
                    if ns.substring(with: candidate) == (gap == 1 ? " " + unit : unit) {
                        r = NSRange(location: r.location, length: r.length + candidate.length)
                        break
                    }
                }
                if r.length != match.range.length { break }
            }
            // "your 14-day average" is a compound adjective, not a reading.
            // Emphasising the 14 in it makes the eye stop at a number that
            // isn't one of yours.
            let end = r.location + r.length
            if end < ns.length, ns.substring(with: NSRange(location: end, length: 1)) == "-" {
                continue
            }
            if let converted = Range(r, in: text) { found.append(converted) }
        }

        // Names of measurements, wherever they appear and however they are cased.
        for name in names {
            var searchFrom = text.startIndex
            while let r = text.range(
                of: name,
                options: [.caseInsensitive],
                range: searchFrom..<text.endIndex
            ) {
                if isWholeWord(r, in: text) { found.append(r) }
                searchFrom = r.upperBound
                if searchFrom >= text.endIndex { break }
            }
        }

        // A name inside a longer name, or a unit already inside a figure, would
        // otherwise be emphasised twice and split the run.
        let sorted = found.sorted {
            $0.lowerBound == $1.lowerBound
                ? $0.upperBound > $1.upperBound
                : $0.lowerBound < $1.lowerBound
        }
        var merged: [Range<String.Index>] = []
        for r in sorted {
            if let last = merged.last, r.lowerBound < last.upperBound {
                if r.upperBound > last.upperBound {
                    merged[merged.count - 1] = last.lowerBound..<r.upperBound
                }
                continue
            }
            merged.append(r)
        }
        return merged
    }

    private static func isWholeWord(_ r: Range<String.Index>, in text: String) -> Bool {
        let before = r.lowerBound == text.startIndex
            ? nil : text[text.index(before: r.lowerBound)]
        let after = r.upperBound == text.endIndex ? nil : text[r.upperBound]
        let boundary: (Character?) -> Bool = { c in
            guard let c else { return true }
            return !(c.isLetter || c.isNumber)
        }
        return boundary(before) && boundary(after)
    }
}

extension Text {
    /// Body text with its measurements and figures set apart.
    init(emphasising sentence: String,
         base: Font = Theme.serifBody(17),
         strong: Font = Theme.serif(18),
         baseColor: Color = Theme.mid,
         strongColor: Color = Theme.ink) {
        self.init(Emphasis.render(
            sentence, base: base, strong: strong, baseColor: baseColor, strongColor: strongColor
        ))
    }
}
