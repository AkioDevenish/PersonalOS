import Foundation

/// How far back a ledger screen looks.
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
