import Foundation

/// Turning integer minor units into something a person reads, and back.
enum Money {
    /// The currency this phone is set up for, or US dollars if it names none.
    static var deviceDefault: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// How many minor units make a major one, for this currency.
    static func fractionDigits(_ currency: String) -> Int {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.maximumFractionDigits
    }

    private static func divisor(_ currency: String) -> Double {
        pow(10.0, Double(fractionDigits(currency)))
    }

    /// "$12.30", in the reader's locale conventions but the given currency.
    static func text(_ minor: Int, _ currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        let major = abs(Double(minor) / divisor(currency))
        return f.string(from: NSNumber(value: major)) ?? String(format: "%.2f", major)
    }

    /// Minor units as a bare major-unit number, for a text field.
    static func major(_ minor: Int, _ currency: String) -> String {
        let digits = fractionDigits(currency)
        return String(format: "%.\(digits)f", Double(minor) / pow(10.0, Double(digits)))
    }

    /// What someone typed, as whole minor units. Nil for anything that isn't a sane amount.
    static func minor(from text: String, currency: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let major = Double(cleaned), major.isFinite, abs(major) < 1_000_000_000 else { return nil }
        return Int((major * divisor(currency)).rounded())
    }
}
