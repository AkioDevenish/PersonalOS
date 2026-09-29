import Testing
@testable import Forklore

/// The meal engine answers in loosely labelled text; this is what turns it into cards.
@MainActor
struct MealReadingTests {
    @Test func stripsTheModelsMarkup() {
        let cleaned = MealReading.clean("**Callaloo** — rich in iron\n\n\n\n## [MEAL_REC]Pelau")
        #expect(cleaned == "Callaloo, rich in iron\n\nPelau")
    }

    @Test func splitsMealsAtEachName() {
        let raw = """
        Name: Callaloo with crab
        Why: Leafy greens and protein.
        Macros: 30g protein
        GI score: Low
        Prep: 40 minutes
        Name: Doubles
        Why: A lighter breakfast.
        """
        let parsed = MealReading.parse(raw)
        #expect(parsed.meals.count == 2)
        #expect(parsed.meals[0].name == "Callaloo with crab")
        #expect(parsed.meals[0].macros == "30g protein")
        #expect(parsed.meals[0].glycaemic == "Low")
        #expect(parsed.meals[0].prep == "40 minutes")
        #expect(parsed.meals[1].name == "Doubles")
        #expect(parsed.meals[1].why == "A lighter breakfast.")
    }

    @Test func joinsAWrappedLineOntoTheFieldItContinues() {
        let parsed = MealReading.parse("Name: Pelau\nWhy: One pot,\nand it keeps well.")
        #expect(parsed.meals.first?.why == "One pot, and it keeps well.")
    }

    @Test func pullsOutTheInsight() {
        let parsed = MealReading.parse("[NUTRITION_INSIGHT] Your glucose settles faster after walks.")
        #expect(parsed.insight == "Your glucose settles faster after walks.")
        #expect(parsed.meals.isEmpty)
    }

    @Test func keepsWhatItCannotPlaceAsProse() {
        let parsed = MealReading.parse("Here are some ideas.\n\nEnjoy.")
        #expect(parsed.meals.isEmpty)
        #expect(parsed.prose == "Here are some ideas.\n\nEnjoy.")
    }

    @Test func aColonInASentenceIsNotAField() {
        let parsed = MealReading.parse("Tip: eat slowly")
        #expect(parsed.meals.isEmpty)
        #expect(parsed.prose == "Tip: eat slowly")
    }
}
