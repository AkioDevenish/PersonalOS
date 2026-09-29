import Foundation

/// Formatters, built once.
enum Formatters {
    /// "Tuesday · March 4", the kicker over a day's page.
    static let dayAndDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f
    }()

    /// "Tuesday", for a sentence about a typical one.
    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    /// Whole numbers with the reader's thousands separator.
    static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
