import Foundation
import Testing
@testable import PersonalOSHealth

/// The phone reads HealthKit in its own units; the server stores one canonical unit per metric.
@MainActor
struct CanonicalMapperTests {
    private func snapshot(
        steps: Double? = nil,
        distanceKm: Double? = nil,
        walkingSpeedKmh: Double? = nil,
        walkingSteadiness: Double? = nil,
        totalSleepHours: Double? = nil,
        restingHeartRate: Double? = nil
    ) -> HealthSnapshot {
        HealthSnapshot(
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
            steps: steps,
            distanceKm: distanceKm,
            flightsClimbed: nil,
            walkingSpeedKmh: walkingSpeedKmh,
            walkingSteadiness: walkingSteadiness,
            avgBloodGlucoseMgdl: nil,
            dietaryCarbohydratesG: nil,
            insulinDeliveryIu: nil,
            walkingAsymmetryPct: nil,
            walkingStepLength: nil,
            walkingDoubleSupportPct: nil,
            stairAscentSpeed: nil,
            activeEnergyBurned: nil,
            basalEnergyBurned: nil,
            headphoneAudioExposure: nil,
            mindfulSessionMins: nil,
            timeInDaylight: nil,
            totalSleepHours: totalSleepHours,
            restingHeartRate: restingHeartRate,
            stateOfMindLabels: nil,
            stateOfMindValence: nil
        )
    }

    private func sample(_ metric: String, in samples: [CanonicalSample]) -> CanonicalSample? {
        samples.first { $0.metric == metric }
    }

    @Test func convertsToTheServersUnits() throws {
        let out = CanonicalMapper.samples(
            from: snapshot(distanceKm: 2.5, walkingSpeedKmh: 3.6, walkingSteadiness: 0.82, totalSleepHours: 7.5),
            device: "iPhone"
        )

        let distance = try #require(sample("distance", in: out))
        #expect(distance.value == 2500)
        #expect(distance.unit == "m")

        let speed = try #require(sample("walking_speed", in: out))
        #expect(abs(speed.value - 1) < 1e-9)
        #expect(speed.unit == "m/s")

        let sleep = try #require(sample("sleep_duration", in: out))
        #expect(sleep.value == 450)
        #expect(sleep.unit == "min")

        let steadiness = try #require(sample("walking_steadiness", in: out))
        #expect(abs(steadiness.value - 82) < 1e-9)
        #expect(steadiness.unit == "pct")
    }

    @Test func leavesOutWhatWasNotMeasured() {
        let out = CanonicalMapper.samples(from: snapshot(steps: 4200), device: nil)
        #expect(out.map(\.metric) == ["steps"])
    }

    @Test func dropsValuesThatAreNotNumbers() {
        let out = CanonicalMapper.samples(from: snapshot(steps: .nan, restingHeartRate: .infinity), device: nil)
        #expect(out.isEmpty)
    }

    @Test func stampsEverySampleInEpochMilliseconds() {
        let out = CanonicalMapper.samples(from: snapshot(steps: 1, restingHeartRate: 60), device: "Watch")
        #expect(out.allSatisfy { $0.recorded_at == 1_700_000_000_000 && $0.device == "Watch" })
    }
}
