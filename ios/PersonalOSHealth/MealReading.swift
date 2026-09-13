import SwiftUI

/// What the meal engine actually returns, taken apart.
///
/// The prompt asks for `**Name:**`, `**Why:**`, `**Macros:**`, `**Prep:**` and
/// a closing `[NUTRITION_INSIGHT]`, and the app was printing all of that
/// verbatim — asterisks, tags, the model's own idea of blank lines. Markdown
/// shown to someone who never asked for markdown is a leak of the plumbing,
/// and this design has real typography to say the same things: a name is a
/// serif line, a reason is body text, macros are a tracked caps figure.
///
/// So the structure is read out of the text and thrown away, and what's left is
/// laid out. The parse is deliberately forgiving — models drop a marker or
/// double one — and anything it cannot place survives as prose rather than
/// being silently dropped.
struct MealSuggestion: Identifiable {
    let id = UUID()
    var name = ""
    var why = ""
    var macros = ""
    var glycaemic = ""
    var prep = ""

    var isEmpty: Bool {
        name.isEmpty && why.isEmpty && macros.isEmpty && prep.isEmpty
    }
}

enum MealReading {
    struct Parsed {
        var meals: [MealSuggestion] = []
        var insight = ""
        /// Anything the parser couldn't place. Shown rather than discarded: a
        /// model that ignores the format still said something.
        var prose = ""

        var isEmpty: Bool { meals.isEmpty && insight.isEmpty && prose.isEmpty }
    }

    /// Strips the model's own markup. Asterisks, the [MEAL_REC] tag it was told
    /// to emit, and the runs of blank lines it likes to leave behind.
    static func clean(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "**", with: "")
        // Models reach for the em dash constantly and it reads as machine
        // prose. Cleaned on arrival rather than only asked for in the prompt,
        // because asking is a request and this is a rule.
        out = out.replacingOccurrences(of: " — ", with: ", ")
        out = out.replacingOccurrences(of: "—", with: ", ")
        out = out.replacingOccurrences(of: "[MEAL_REC]", with: "")
        out = out.replacingOccurrences(of: "##", with: "")
        out = out
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        while out.contains("\n\n\n") {
            out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let fields = ["name", "why", "macros", "gi score", "gi", "prep"]

    static func parse(_ raw: String) -> Parsed {
        var result = Parsed()
        var current: MealSuggestion?
        var lastField = ""
        var loose: [String] = []

        func closeCurrent() {
            if let c = current, !c.isEmpty { result.meals.append(c) }
            current = nil
            lastField = ""
        }

        for line in clean(raw).split(separator: "\n", omittingEmptySubsequences: false) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { continue }

            if let range = text.range(of: "[NUTRITION_INSIGHT]") {
                result.insight = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                continue
            }

            // "Name: Callaloo with crab" — the field is whatever precedes the
            // first colon, when that is short enough to be a label.
            if let colon = text.firstIndex(of: ":") {
                let label = text[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(text[text.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)

                if fields.contains(label) {
                    if label == "name" { closeCurrent(); current = MealSuggestion() }
                    if current == nil { current = MealSuggestion() }
                    switch label {
                    case "name":            current?.name = value
                    case "why":             current?.why = value
                    case "macros":          current?.macros = value
                    case "gi score", "gi":  current?.glycaemic = value
                    case "prep":            current?.prep = value
                    default: break
                    }
                    lastField = label
                    continue
                }
            }

            // A continuation of whatever field we were in — models wrap.
            if current != nil, !lastField.isEmpty {
                switch lastField {
                case "why":   current?.why += " " + text
                case "prep":  current?.prep += " " + text
                default:      loose.append(text)
                }
                continue
            }

            loose.append(text)
        }
        closeCurrent()
        result.prose = loose.joined(separator: "\n\n")
        return result
    }

    /// The parsed reading, as the runs the typewriter writes out.
    ///
    /// Built here rather than in the view so the order things appear in is the
    /// order they were written in — the name lands, then the reason, then the
    /// numbers, which is how you'd read it aloud.
    static func runs(for parsed: Parsed) -> [TypedRun] {
        var runs: [TypedRun] = []

        for (i, meal) in parsed.meals.enumerated() {
            if !meal.name.isEmpty {
                runs.append(TypedRun(
                    text: meal.name,
                    font: Theme.serif(24),
                    color: Theme.ink,
                    lineSpacing: 2,
                    topPadding: i == 0 ? 0 : 26
                ))
            }
            if !meal.why.isEmpty {
                runs.append(TypedRun(
                    text: meal.why,
                    font: Theme.serifBody(17),
                    color: Theme.mid,
                    lineSpacing: 6,
                    topPadding: 6
                ))
            }
            let figures = [meal.macros, meal.glycaemic.isEmpty ? "" : "GI \(meal.glycaemic)"]
                .filter { !$0.isEmpty }
                .joined(separator: "  ·  ")
            if !figures.isEmpty {
                runs.append(TypedRun(
                    text: figures,
                    font: Theme.sans(10),
                    color: Theme.dust,
                    tracking: 1.4,
                    lineSpacing: 3,
                    topPadding: 10,
                    uppercased: true
                ))
            }
            if !meal.prep.isEmpty {
                runs.append(TypedRun(
                    text: meal.prep,
                    font: Theme.serifBody(15.5),
                    color: Theme.mid,
                    lineSpacing: 5,
                    topPadding: 8
                ))
            }
        }

        if !parsed.prose.isEmpty {
            runs.append(TypedRun(
                text: parsed.prose,
                font: Theme.serifBody(17),
                color: Theme.ink,
                lineSpacing: 6,
                topPadding: runs.isEmpty ? 0 : 24
            ))
        }

        if !parsed.insight.isEmpty {
            runs.append(TypedRun(
                text: parsed.insight,
                font: Theme.serifItalic(17),
                color: Theme.ink,
                lineSpacing: 6,
                topPadding: 26
            ))
        }

        return runs
    }
}
