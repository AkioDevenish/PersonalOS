import Foundation

/// Today, measured against your own ordinary version of this weekday.
struct Baseline {
    let spec: MetricSpec
    /// The name of the day, for the sentence: "a typical Tuesday".
    let weekday: String
    /// The middle of your recent same-weekdays, in the metric's own unit.
    let typical: Double
    /// How many days went into it.
    let samples: Int

    /// Where today stands, phrased in terms of better and worse rather than more and less.
    enum Standing { case better, ordinary, worse }

    /// Inside a tenth of your usual is not a difference worth remarking on.
    private static let margin = 0.10

    func standing(today: Double) -> Standing {
        guard typical > 0 else { return .ordinary }
        let ratio = today / typical
        guard abs(ratio - 1) > Self.margin else { return .ordinary }

        let higher = ratio > 1
        switch spec.goal {
        case .atLeast: return higher ? .better : .worse
        case .atMost:  return higher ? .worse : .better
        // A number with no better direction still has a usual.
        case .none:    return .ordinary
        }
    }

    /// The line under the figure.
    func sentence(today: Double) -> String {
        guard typical > 0 else { return "No usual \(weekday) to compare with yet" }

        switch standing(today: today) {
        case .ordinary:
            return spec.goal == .none
                ? "About usual for a \(weekday)"
                : "A typical \(weekday)"
        case .better:
            return spec.goal == .atMost
                ? "Lower than a typical \(weekday)"
                : "Ahead of a typical \(weekday)"
        case .worse:
            return spec.goal == .atMost
                ? "Higher than a typical \(weekday)"
                : "Quieter than a typical \(weekday)"
        }
    }

    /// Builds the comparison for one metric, or nothing when there is too little history to say
    /// anything honest.
    static func of(
        _ spec: MetricSpec,
        history: [HealthSnapshot],
        on day: Date = Date(),
        calendar: Calendar = .current
    ) -> Baseline? {
        let weekday = calendar.component(.weekday, from: day)

        let values = history
            .filter { calendar.component(.weekday, from: $0.recordedAt) == weekday }
            // Today is not evidence about what is typical for today.
            .filter { !calendar.isDate($0.recordedAt, inSameDayAs: day) }
            .compactMap { spec.value($0) }
            .filter { $0.isFinite && $0 > 0 }
            .sorted()

        // Two same-weekdays is the least that can be called a habit.
        guard values.count >= 2 else { return nil }

        let mid = values.count / 2
        let median = values.count.isMultiple(of: 2)
            ? (values[mid - 1] + values[mid]) / 2
            : values[mid]

        return Baseline(
            spec: spec,
            weekday: Formatters.weekday.string(from: day),
            typical: median,
            samples: values.count
        )
    }
}
