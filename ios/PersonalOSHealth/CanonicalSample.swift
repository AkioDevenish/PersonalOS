import Foundation

/// One measurement in the server's vocabulary.
///
/// The old payload was one fat object with a column per metric, so adding a
/// metric meant changing the app, the API and the database together. This is
/// flat and self-describing: metric name, value, unit, when.
struct CanonicalSample: Encodable {
    let metric: String
    let value: Double
    let unit: String
    /// Epoch milliseconds — what convex/health/samples.ts expects.
    let recorded_at: Int64
    let device: String?
}

/// Translates a HealthSnapshot into canonical samples.
///
/// Every conversion here is deliberate and must match METRICS in
/// convex/health/metrics.ts exactly. The server rejects a sample whose unit
/// doesn't match rather than guessing, so a mistake surfaces as a rejection
/// with a reason instead of a plausible-looking number that is wrong by a
/// factor of a thousand.
///
/// Note the round trip: HealthKit reads metres and m/s, HealthSnapshot stores
/// km and km/h for display, and the canonical form is back in metres and m/s.
/// Those factors below are undoing conversions done upstream.
enum CanonicalMapper {

    static func samples(from snapshot: HealthSnapshot, device: String?) -> [CanonicalSample] {
        let at = Int64(snapshot.recordedAt.timeIntervalSince1970 * 1000)
        var out: [CanonicalSample] = []

        func add(_ metric: String, _ value: Double?, _ unit: String, scale: Double = 1) {
            guard let value, value.isFinite else { return }
            out.append(
                CanonicalSample(
                    metric: metric,
                    value: value * scale,
                    unit: unit,
                    recorded_at: at,
                    device: device
                )
            )
        }

        add("steps", snapshot.steps, "count")
        add("flights_climbed", snapshot.flightsClimbed, "count")

        // snapshot holds km; canonical is metres
        add("distance", snapshot.distanceKm, "m", scale: 1000)

        // snapshot holds km/h; canonical is m/s
        add("walking_speed", snapshot.walkingSpeedKmh, "m/s", scale: 1 / 3.6)

        // snapshot holds hours; canonical is minutes
        add("sleep_duration", snapshot.totalSleepHours, "min", scale: 60)

        add("mindful_minutes", snapshot.mindfulSessionMins, "min")
        add("time_in_daylight", snapshot.timeInDaylight, "min")

        add("active_energy", snapshot.activeEnergyBurned, "kcal")
        add("basal_energy", snapshot.basalEnergyBurned, "kcal")

        add("blood_glucose", snapshot.avgBloodGlucoseMgdl, "mg/dL")
        add("dietary_carbohydrates", snapshot.dietaryCarbohydratesG, "g")
        add("insulin_delivery", snapshot.insulinDeliveryIu, "IU")

        // HKUnit.percent() yields a fraction where 1.0 == 100%.
        // Canonical "pct" is 0–100, so these scale up.
        add("walking_steadiness", snapshot.walkingSteadiness, "pct", scale: 100)
        add("walking_asymmetry", snapshot.walkingAsymmetryPct, "pct", scale: 100)
        add("walking_double_support", snapshot.walkingDoubleSupportPct, "pct", scale: 100)

        add("walking_step_length", snapshot.walkingStepLength, "m")
        add("stair_ascent_speed", snapshot.stairAscentSpeed, "m/s")
        add("headphone_audio_exposure", snapshot.headphoneAudioExposure, "dB")

        // Deliberately not mapped: stateOfMindLabels is text and
        // stateOfMindValence has no canonical metric yet. The samples table is
        // numeric-only; state of mind needs its own shape.

        return out
    }
}
