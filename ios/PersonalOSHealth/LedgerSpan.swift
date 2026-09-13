import Foundation

/// How far back a ledger screen looks.
///
/// Shared by money and time so the two tabs answer the same question over the
/// same window, and switching between them compares like with like.
enum LedgerSpan: CaseIterable, Hashable {
    case week, month, year

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// The heading a total sits under.
    var heading: String {
        switch self {
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }

    /// The window, running from the start of the calendar period up to now.
    ///
    /// Calendar units rather than arithmetic: a month is not thirty days, and
    /// somebody looking at March expects March rather than the last thirty
    /// days of it. `to` is now rather than the period's end, so nothing dated
    /// in the future gets counted by accident.
    func window(now: Date = Date(), calendar: Calendar = .current) -> (from: Date, to: Date) {
        let unit: Calendar.Component
        switch self {
        case .week: unit = .weekOfYear
        case .month: unit = .month
        case .year: unit = .year
        }
        let start = calendar.dateInterval(of: unit, for: now)?.start ?? now
        return (start, now)
    }
}
