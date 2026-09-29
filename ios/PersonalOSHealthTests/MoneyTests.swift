import Testing
@testable import PersonalOSHealth

/// Prices are stored as whole minor units; these are the conversions a practitioner's price goes
/// through on its way in and out of a text field.
@MainActor
struct MoneyTests {
    @Test func knowsHowManyMinorUnitsACurrencyHas() {
        #expect(Money.fractionDigits("USD") == 2)
        #expect(Money.fractionDigits("TTD") == 2)
        #expect(Money.fractionDigits("JPY") == 0)
    }

    @Test func readsWhatSomeoneTyped() {
        #expect(Money.minor(from: "12.30", currency: "USD") == 1230)
        #expect(Money.minor(from: " 40 ", currency: "TTD") == 4000)
        #expect(Money.minor(from: "500", currency: "JPY") == 500)
    }

    @Test func acceptsACommaAsTheDecimalMark() {
        #expect(Money.minor(from: "12,30", currency: "EUR") == 1230)
    }

    @Test func refusesAnythingThatIsNotASaneAmount() {
        #expect(Money.minor(from: "", currency: "USD") == nil)
        #expect(Money.minor(from: "twelve", currency: "USD") == nil)
        #expect(Money.minor(from: "inf", currency: "USD") == nil)
        #expect(Money.minor(from: "1000000000", currency: "USD") == nil)
    }

    @Test func roundsToWholeMinorUnits() {
        #expect(Money.minor(from: "0.1", currency: "USD") == 10)
        #expect(Money.minor(from: "19.999", currency: "USD") == 2000)
    }

    @Test func writesMinorUnitsBackForATextField() {
        #expect(Money.major(1230, "USD") == "12.30")
        #expect(Money.major(500, "JPY") == "500")
        #expect(Money.minor(from: Money.major(4000, "TTD"), currency: "TTD") == 4000)
    }

    @Test func showsThePriceWithoutASign() {
        #expect(Money.text(1230, "USD").contains("12.30"))
        #expect(Money.text(-1230, "USD") == Money.text(1230, "USD"))
    }
}
