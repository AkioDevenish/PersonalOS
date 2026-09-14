import Foundation

/// Formatters, built once.
///
/// `DateFormatter()` and `NumberFormatter()` are not cheap objects — each one
/// builds an ICU formatter behind it — and these were being constructed inside
/// computed properties that views read while drawing. That is fine at one a
/// second and not fine during a drag, when the page redraws every frame and
/// each frame was building two or three of them on the main thread.
///
/// Configured at creation and only ever read afterwards, which is the case
/// Foundation supports being shared.
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
