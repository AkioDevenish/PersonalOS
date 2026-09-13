import Foundation

/// Today's steps as they accumulated, against the way this weekday usually goes.
///
/// The written comparison in `Baseline` answers "was today busier than usual".
/// This answers the more useful question earlier in the day: *by now*, am I
/// ahead or behind? A day that ends level can still have been two hours late
/// all afternoon, and a total at bedtime cannot show that.
struct DayCurve {
    /// Cumulative steps at the end of each hour that has already passed today.
    let today: [Double]
    /// The same shape for a usual day of this weekday, all twenty-four hours.
    let typical: [Double]
    let weekday: String
    /// How many past same-weekdays the typical curve is drawn from.
    let samples: Int

    var todayTotal: Double { today.last ?? 0 }
    var typicalTotal: Double { typical.last ?? 0 }

    /// What a usual day of this weekday had reached by the hour today has got
    /// to. This is the honest comparison: today's half-finished total against
    /// a usual day's total is not a comparison at all.
    var typicalByNow: Double {
        guard !today.isEmpty, typical.count >= today.count else { return 0 }
        return typical[today.count - 1]
    }

    /// Reads for the subtitle: how far ahead or behind, in steps.
    var difference: Double { todayTotal - typicalByNow }

    static func build(
        from hourly: [Date: Double],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DayCurve? {
        let weekday = calendar.component(.weekday, from: now)
        let todayStart = calendar.startOfDay(for: now)

        // Bucket every reading into the day it belongs to, at its hour.
        var byDay: [Date: [Int: Double]] = [:]
        for (hourStart, value) in hourly {
            let day = calendar.startOfDay(for: hourStart)
            let hour = calendar.component(.hour, from: hourStart)
            byDay[day, default: [:]][hour, default: 0] += value
        }

        /// Running total across the hours, so hour 9 holds everything up to
        /// and including hour 9.
        func cumulative(_ hours: [Int: Double], through last: Int) -> [Double] {
            var running = 0.0
            return (0...last).map { h in
                running += hours[h] ?? 0
                return running
            }
        }

        let hourNow = calendar.component(.hour, from: now)
        let todayCurve = cumulative(byDay[todayStart] ?? [:], through: hourNow)

        // Past days of the same weekday, each as a full 24-hour curve.
        let pastCurves = byDay
            .filter { day, _ in
                day != todayStart && calendar.component(.weekday, from: day) == weekday
            }
            .map { cumulative($0.value, through: 23) }

        // Two is the least that can be called usual. One previous Tuesday is
        // an anecdote drawn as if it were a pattern.
        guard pastCurves.count >= 2 else { return nil }

        // Median hour by hour rather than mean: a single enormous day should
        // not bend the whole curve upward.
        let typicalCurve = (0...23).map { hour -> Double in
            let values = pastCurves.compactMap { $0.indices.contains(hour) ? $0[hour] : nil }.sorted()
            guard !values.isEmpty else { return 0 }
            let mid = values.count / 2
            return values.count.isMultiple(of: 2)
                ? (values[mid - 1] + values[mid]) / 2
                : values[mid]
        }

        let name = DateFormatter()
        name.dateFormat = "EEEE"

        return DayCurve(
            today: todayCurve,
            typical: typicalCurve,
            weekday: name.string(from: now),
            samples: pastCurves.count
        )
    }
}
