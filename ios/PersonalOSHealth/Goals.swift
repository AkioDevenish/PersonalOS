import Foundation

/// What you are trying to do, in numbers.
///
/// The briefing used to close with advice invented from thresholds this app
/// chose: under four thousand steps was "the day still owes you a walk",
/// because four thousand was a number in a source file. That is a guess about
/// a stranger. A goal is the same sentence with the guessing removed, and it
/// is the only part of the app the person, rather than the model, gets to
/// decide.
///
/// Kept on the phone rather than in Convex. A goal is small, personal, and
/// wanted offline — the briefing composes with no network, and it would be a
/// poor trade to have it lose your targets when the signal goes.
enum Goals {
    private static let key = "personal_os_goals"

    /// Metric id to target. Absent means no goal, which is different from a
    /// target of zero.
    static var all: [String: Double] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func target(_ id: String) -> Double? { all[id] }

    static func set(_ id: String, _ value: Double?) {
        var current = all
        if let value, value > 0 { current[id] = value } else { current.removeValue(forKey: id) }
        all = current
    }

    /// Reads a number a person typed, or one this app printed back to them.
    ///
    /// `Double("8,000")` is nil, and the goals screen was printing targets with
    /// a thousands separator and then parsing them back, so simply opening the
    /// screen deleted every goal of a thousand or more. Grouping separators are
    /// stripped before parsing, and a locale that writes a comma for the
    /// decimal point is honoured, so a European "7,5" is seven and a half
    /// rather than seventy-five.
    static func number(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let parsed = formatter.number(from: trimmed)?.doubleValue { return parsed }

        // Fall back to the plain reading, for a keypad that gave us a bare
        // "7.5" in a locale that would not have written it that way.
        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }

    /// A target as a person should see it in an editable field: no grouping
    /// separator, because what is printed here has to survive being read back.
    static func editable(_ spec: MetricSpec, _ value: Double) -> String {
        spec.precision == 0
            ? String(Int(value.rounded()))
            : String(format: "%.\(spec.precision)f", value)
    }

    /// The metrics a goal can be set on, in the order the catalogue lists them.
    static var settable: [MetricSpec] { Metrics.all.filter { $0.goal.isSettable } }

    /// Sensible opening numbers, so the screen isn't a wall of empty fields.
    ///
    /// Offered, never applied: a suggestion you have to accept is a suggestion,
    /// and a number written in for you is this app deciding again.
    static func suggestion(for spec: MetricSpec) -> Double? {
        switch spec.id {
        case "steps":         return 8000
        case "sleep":         return 7.5
        case "active_energy": return 500
        case "daylight":      return 30
        case "mindful":       return 10
        case "flights":       return 10
        case "distance":      return 5
        case "resting_hr":    return 60
        case "glucose":       return 110
        default:              return nil
        }
    }

    // MARK: Reading the day against them

    struct Progress: Identifiable {
        let spec: MetricSpec
        let target: Double
        let actual: Double?

        var id: String { spec.id }

        /// Where the day stands against this goal.
        ///
        /// Three states, not two. A floor with nothing recorded is genuinely
        /// missed: no steps taken is no steps taken. A ceiling with nothing
        /// recorded is neither met nor missed, because nothing was measured
        /// and so nothing was exceeded. Reporting it as a miss told people
        /// they had broken a glucose limit on a day they never tested.
        enum State { case met, missed, unmeasured }

        var state: State {
            guard let actual else {
                return spec.goal == .atMost ? .unmeasured : .missed
            }
            let ok = spec.goal == .atMost ? actual <= target : actual >= target
            return ok ? .met : .missed
        }

        var met: Bool { state == .met }
        /// Whether the day says anything at all about this goal.
        var judged: Bool { state != .unmeasured }

        /// How far short, in the metric's own units. Nil unless it was missed.
        var shortfall: Double? {
            guard state == .missed else { return nil }
            guard let actual else { return target }
            return spec.goal == .atMost ? actual - target : target - actual
        }
    }

    /// Every goal, measured against a day. Unmet first, because those are the
    /// ones the closing list is for.
    static func progress(on snapshot: HealthSnapshot?) -> [Progress] {
        settable.compactMap { spec -> Progress? in
            guard let target = target(spec.id) else { return nil }
            return Progress(spec: spec, target: target, actual: snapshot.flatMap { spec.value($0) })
        }
        .sorted { a, b in
            func rank(_ p: Progress) -> Int {
                switch p.state {
                case .missed: return 0
                case .unmeasured: return 1
                case .met: return 2
                }
            }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            return a.spec.id < b.spec.id
        }
    }
}
