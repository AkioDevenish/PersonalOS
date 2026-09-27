import Foundation
import HealthKit

/// The menstrual cycle, counted rather than predicted at you.
enum Cycle {

    /// One day that was bled on, as Apple Health records it.
    struct Day: Hashable {
        let date: Date
        let flow: Flow
        /// Apple marks the first day of a cycle with its own metadata key.
        let marksCycleStart: Bool
    }

    /// How heavy, in Apple's five values.
    enum Flow: Int, CaseIterable, Hashable {
        case unspecified = 1, light = 2, medium = 3, heavy = 4, none = 5

        var label: String {
            switch self {
            case .unspecified: return "Bleeding"
            case .light: return "Light"
            case .medium: return "Medium"
            case .heavy: return "Heavy"
            case .none: return "None"
            }
        }

        /// Whether this value means a day was actually bled on.
        var isBleeding: Bool { self != .none }

        var category: HKCategoryValueVaginalBleeding {
            HKCategoryValueVaginalBleeding(rawValue: rawValue) ?? .unspecified
        }
    }

    /// One run of bleeding, and the cycle it opened.
    struct Period: Hashable, Identifiable {
        let start: Date
        /// How many consecutive days were bled on.
        let days: Int
        var id: Date { start }
    }

    // MARK: Working out where you are

    /// Everything the screen needs, derived in one pass.
    struct Reading {
        /// Periods found, newest first.
        let periods: [Period]
        /// Which day of the current cycle today is, counting the first day of the last period as
        /// day one.
        let day: Int?
        /// The middle of the gaps between recent periods.
        let typicalLength: Int?
        /// The middle of recent period lengths.
        let typicalPeriodDays: Int?
        /// When the next one is expected, if there is enough history to say.
        let nextExpected: Date?
        /// Whether today has a bleeding record already.
        let bleedingToday: Flow?
        /// The day this was worked out for.
        let asOf: Date

        static let empty = Reading(
            periods: [], day: nil, typicalLength: nil,
            typicalPeriodDays: nil, nextExpected: nil, bleedingToday: nil,
            asOf: Date()
        )

        /// Two complete cycles is the least that can be called a pattern, the same threshold the
        /// weekday baseline uses and for the same reason: one previous cycle is an anecdote, and
        /// predicting from it reads as authority the number has not earned.
        var canPredict: Bool { typicalLength != nil }

        var phase: Phase? {
            guard let day, let typicalLength else { return nil }
            return Phase.of(day: day, in: typicalLength, bleedingFor: typicalPeriodDays ?? 5)
        }

        /// Days until the next expected period, negative when it is late.
        var daysAway: Int? {
            guard let nextExpected else { return nil }
            let calendar = Calendar.current
            return calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: asOf),
                to: calendar.startOfDay(for: nextExpected)
            ).day
        }
    }

    /// The four phases, which is how the day is usually spoken about.
    enum Phase: String, CaseIterable {
        case menstrual, follicular, ovulatory, luteal

        static func of(day: Int, in length: Int, bleedingFor bleedDays: Int) -> Phase {
            if day <= max(1, bleedDays) { return .menstrual }
            let ovulation = max(bleedDays + 1, length - 14)
            if day >= ovulation - 2 && day <= ovulation + 1 { return .ovulatory }
            if day < ovulation { return .follicular }
            return .luteal
        }

        /// The days this phase covers in a cycle of this length.
        func days(in length: Int, bleedingFor bleedDays: Int) -> ClosedRange<Int>? {
            let mine = (1...max(1, length)).filter { Phase.of(day: $0, in: length, bleedingFor: bleedDays) == self }
            guard let first = mine.first, let last = mine.last else { return nil }
            return first...last
        }

        /// The one picture for each: a drop, then the day rising, its height, and the moon as it
        /// winds down.
        var symbol: String {
            switch self {
            case .menstrual: return "drop.fill"
            case .follicular: return "sunrise.fill"
            case .ovulatory: return "sun.max.fill"
            case .luteal: return "moon.fill"
            }
        }

        var title: String {
            switch self {
            case .menstrual: return "Bleeding"
            case .follicular: return "Follicular"
            case .ovulatory: return "Ovulatory"
            case .luteal: return "Luteal"
            }
        }

        /// One line, in the register the rest of the app writes in.
        var note: String {
            switch self {
            case .menstrual:
                return "The cycle begins again. Energy is usually lowest here."
            case .follicular:
                return "Energy builds. Often the easiest stretch of the month."
            case .ovulatory:
                return "Mid-cycle. Estimated by counting, not measured."
            case .luteal:
                return "The run-up to your period. Often the heaviest-feeling week."
            }
        }
    }

    // MARK: The arithmetic

    /// Groups bled-on days into periods, newest first.
    static func periods(from days: [Day], calendar: Calendar = .current) -> [Period] {
        let bleeding = days
            .filter { $0.flow.isBleeding }
            .map { Day(date: calendar.startOfDay(for: $0.date), flow: $0.flow, marksCycleStart: $0.marksCycleStart) }
            .sorted { $0.date < $1.date }

        guard !bleeding.isEmpty else { return [] }

        var out: [Period] = []
        var runStart = bleeding[0].date
        var runDays = 1

        for (previous, current) in zip(bleeding, bleeding.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous.date, to: current.date).day ?? 0
            // The same day recorded twice is one day.
            if gap == 0 { continue }
            if current.marksCycleStart || gap > 2 {
                out.append(Period(start: runStart, days: runDays))
                runStart = current.date
                runDays = 1
            } else {
                runDays += gap
            }
        }
        out.append(Period(start: runStart, days: runDays))
        return out.reversed()
    }

    /// The middle value, which one unusual month cannot move.
    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// Reads a run of days into everything the screen shows.
    static func read(_ days: [Day], on today: Date = Date(), calendar: Calendar = .current) -> Reading {
        let found = periods(from: days, calendar: calendar)
        let start = calendar.startOfDay(for: today)

        // Gaps between consecutive starts, newest first.
        let gaps: [Int] = zip(found, found.dropFirst()).compactMap { newer, older in
            let g = calendar.dateComponents([.day], from: older.start, to: newer.start).day ?? 0
            return (21...45).contains(g) ? g : nil
        }
        let typical = gaps.count >= 2 ? median(gaps) : nil
        let typicalDays = median(found.prefix(6).map(\.days))

        let day = found.first.flatMap {
            calendar.dateComponents([.day], from: $0.start, to: start).day.map { $0 + 1 }
        }

        let next = (typical != nil && found.first != nil)
            ? calendar.date(byAdding: .day, value: typical!, to: found.first!.start)
            : nil

        let todayFlow = days.first { calendar.isDate($0.date, inSameDayAs: start) }?.flow

        return Reading(
            periods: found,
            // A cycle day only means something while it is plausibly the current cycle.
            day: (day.map { $0 >= 1 && $0 <= 60 } == true) ? day : nil,
            typicalLength: typical,
            typicalPeriodDays: typicalDays,
            nextExpected: next,
            bleedingToday: todayFlow,
            asOf: start
        )
    }
}
