import Foundation

/// What you are trying to do, in numbers.
enum Goals {
    private static let key = "personal_os_goals"

    /// Decoded once and kept.
    private static var cache: [String: Double]?

    /// Metric id to target.
    static var all: [String: Double] {
        get {
            if let cache { return cache }
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            else {
                cache = [:]
                return [:]
            }
            cache = decoded
            return decoded
        }
        set {
            cache = newValue
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
    static func number(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let parsed = formatter.number(from: trimmed)?.doubleValue { return parsed }

        // Fall back to the plain reading, for a keypad that gave us a bare "7.5" in a locale that
        // would not have written it that way.
        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }

    /// A target as a person should see it in an editable field: no grouping separator, because what
    /// is printed here has to survive being read back.
    static func editable(_ spec: MetricSpec, _ value: Double) -> String {
        spec.precision == 0
            ? String(Int(value.rounded()))
            : String(format: "%.\(spec.precision)f", value)
    }

    /// How much one tap of the stepper moves a target.
    static func step(for spec: MetricSpec) -> Double {
        if spec.precision > 0 { return (suggestion(for: spec) ?? 1) >= 20 ? 1 : 0.5 }
        switch suggestion(for: spec) ?? 100 {
        case 5000...:  return 500
        case 1000..<5000: return 100
        case 100..<1000:  return 10
        default:          return 1
        }
    }

    /// Sensible bounds, so a stepper cannot be pushed somewhere absurd.
    static func range(for spec: MetricSpec) -> ClosedRange<Double> {
        let base = suggestion(for: spec) ?? 100
        return (base / 10)...(base * 4)
    }

    /// The metrics a goal can be set on, in the order the catalogue lists them.
    static var settable: [MetricSpec] { Metrics.all.filter { $0.goal.isSettable } }

    /// Sensible opening numbers, so the screen isn't a wall of empty fields.
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

        /// How far short, in the metric's own units.
        var shortfall: Double? {
            guard state == .missed else { return nil }
            guard let actual else { return target }
            return spec.goal == .atMost ? actual - target : target - actual
        }
    }

    /// Every goal, measured against a day.
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
