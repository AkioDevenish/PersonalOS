import Foundation

/// Today, measured against your own ordinary version of this weekday.
///
/// A step count on its own is a number nobody can grade. Eight thousand is a
/// quiet day for one person and a long one for another, and neither of them
/// learns anything from the figure alone. Measured against what this same
/// person usually does on a Tuesday, the same number becomes a judgement, and
/// that is the whole point of a ledger that reads itself.
///
/// Weekday rather than a rolling average, because weeks have shapes. Comparing
/// a Sunday against the last thirty days mostly discovers that weekends differ
/// from weekdays, which the reader already knew.
struct Baseline {
    let spec: MetricSpec
    /// The name of the day, for the sentence: "a typical Tuesday".
    let weekday: String
    /// The middle of your recent same-weekdays, in the metric's own unit.
    let typical: Double
    /// How many days went into it. Two is thin; the screen says so.
    let samples: Int

    /// Where today stands, phrased in terms of better and worse rather than
    /// more and less.
    ///
    /// The direction matters more than it looks. A resting heart rate above
    /// your usual is a worse day, not a better one, and a comparison that only
    /// knows about bigger and smaller would congratulate you for it.
    enum Standing { case better, ordinary, worse }

    /// Inside a tenth of your usual is not a difference worth remarking on.
    /// Day-to-day noise on most of these metrics is larger than that, and a
    /// page that calls every wobble a change stops being read.
    private static let margin = 0.10

    func standing(today: Double) -> Standing {
        guard typical > 0 else { return .ordinary }
        let ratio = today / typical
        guard abs(ratio - 1) > Self.margin else { return .ordinary }

        let higher = ratio > 1
        switch spec.goal {
        case .atLeast: return higher ? .better : .worse
        case .atMost:  return higher ? .worse : .better
        // A number with no better direction still has a usual. "Longer than"
        // says what happened without pretending it was an achievement.
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

    /// Builds the comparison for one metric, or nothing when there is too
    /// little history to say anything honest.
    ///
    /// The median, not the mean: one holiday with thirty thousand steps should
    /// not redefine what your Tuesday looks like.
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

        // Two same-weekdays is the least that can be called a habit. One is an
        // anecdote, and comparing today against a single previous Tuesday
        // reads as authority the number has not earned.
        guard values.count >= 2 else { return nil }

        let mid = values.count / 2
        let median = values.count.isMultiple(of: 2)
            ? (values[mid - 1] + values[mid]) / 2
            : values[mid]

        let name = DateFormatter()
        name.dateFormat = "EEEE"

        return Baseline(
            spec: spec,
            weekday: name.string(from: day),
            typical: median,
            samples: values.count
        )
    }
}
