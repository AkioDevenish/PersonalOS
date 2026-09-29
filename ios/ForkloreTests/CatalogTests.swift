import Foundation
import Testing
@testable import Forklore

@MainActor
struct MetricCatalogTests {
    @Test func everyMetricHasItsOwnId() {
        let ids = Metrics.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func findsAMetricById() {
        #expect(Metrics.by(id: "resting_hr")?.label == "Resting HR")
        #expect(Metrics.by(id: "nope") == nil)
    }

    @Test func formatsToEachMetricsPrecision() throws {
        let sleep = try #require(Metrics.by(id: "sleep"))
        #expect(sleep.format(7.25) == "7.2" || sleep.format(7.25) == "7.3")
        let steps = try #require(Metrics.by(id: "steps"))
        #expect(steps.format(412.6) == "413")
        #expect(steps.format(.nan) == "·")
    }

    @Test func aGoalOnlyMeansSomethingWithADirection() {
        #expect(GoalDirection.atLeast.isSettable)
        #expect(GoalDirection.atMost.isSettable)
        #expect(!GoalDirection.none.isSettable)
    }
}

/// The server's `health/cuisine:forCountry` answer, as the app decodes it.
@MainActor
struct CuisineBookTests {
    private let json = """
    {
      "threshold": 3,
      "generating": false,
      "generated": true,
      "all": [
        { "key": "doubles", "dish": "Doubles", "votes": 0, "written": true, "mine": false },
        { "key": "kurma", "dish": "Kurma", "votes": 3, "written": false, "mine": true }
      ],
      "canon": ["Doubles", "Kurma"]
    }
    """

    @Test func decodesWhatTheServerSends() throws {
        let book = try JSONDecoder().decode(CuisineClient.Book.self, from: Data(json.utf8))
        #expect(book.threshold == 3)
        #expect(book.all.map(\.dish) == ["Doubles", "Kurma"])
        #expect(book.canon == ["Doubles", "Kurma"])
    }

    @Test func aDishEnoughPeopleNamedCannotBeRejected() throws {
        let book = try JSONDecoder().decode(CuisineClient.Book.self, from: Data(json.utf8))
        #expect(book.all[0].canBeRejected(in: book))
        #expect(!book.all[1].canBeRejected(in: book))
    }

    @Test func theHandWrittenListCannotBeRejectedUntilAGeneratedOneReplacesIt() {
        let written = CuisineClient.Dish(key: "doubles", dish: "Doubles", votes: 0, written: true, mine: false)
        let fallback = CuisineClient.Book(threshold: 3, generating: false, generated: false, all: [written], canon: [])
        #expect(!written.canBeRejected(in: fallback))
    }
}
