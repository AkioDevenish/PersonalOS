import Foundation

/// The five ways a glyph can move.
///
/// Kept deliberately small. Five is enough for every metric in the catalogue to
/// move like the thing it measures, and few enough that the screen reads as one
/// design rather than nineteen ideas.
/// Whether a goal on a metric is a floor, a ceiling, or meaningless.
enum GoalDirection {
    case atLeast    // steps, sleep, daylight: a floor to reach
    case atMost     // resting heart rate, glucose, audio: a ceiling to stay under
    case none       // step length, asymmetry: a number, not an ambition

    var isSettable: Bool { self != .none }
}

enum GlyphMotion {
    /// Continuous, for the four measurements of something that never stops.
    case beat        // a heart, a drop — pulse
    case breathing   // a flame, a sleeping figure — breathe
    /// Periodic, for everything else: movement, and things that turn or land.
    case periodicWiggle
    case periodicRotate
    case periodicBounce
}

/// Every metric the app reads, described once.
///
/// The old dashboard hardcoded each tile and each chart series separately,
/// which is why it drifted — a metric could exist in HealthKit, be synced, and
/// still never appear anywhere. Here a metric is one entry, and the grid, the
/// trends and the correlation view all read from it.
struct MetricSpec: Identifiable, Hashable {
    enum Group: String, CaseIterable {
        case activity = "Physical activity"
        case gait = "Mobility & gait"
        case recovery = "Recovery & environment"
        case metabolic = "Metabolic"
    }

    let id: String
    let label: String
    let group: Group
    let unit: String
    /// Decimal places when shown. Steps want none, walking speed wants two.
    let precision: Int
    /// Whether the number is a total that accumulates over a day (steps,
    /// energy) rather than a level that is true at a moment (heart rate,
    /// walking speed). A total reads as a bar and a level reads as a line, and
    /// getting that backwards makes a chart lie about what it is showing.
    var cumulative: Bool = false
    /// What this metric is called inside a sentence, when the tile label is
    /// too clipped to read as English. "Resting HR" is right on a tile 150
    /// points wide and wrong in a paragraph, where it is a resting heart rate.
    var phrase: String? = nil
    /// Which way is better, and therefore what a goal on it means.
    ///
    /// Without this a target is just a number: 8,000 steps is a floor and 100
    /// mg/dL is a ceiling, and an app that can't tell the difference will
    /// congratulate you for a resting heart rate of 90. `none` is for the
    /// measures where more is not better and less is not better either.
    var goal: GoalDirection = .none
    /// How this metric's glyph moves.
    ///
    /// Every glyph moves now. It used to be four — a heart, a flame, a drop, a
    /// moon — on the reasoning that a step count which throbs is decoration
    /// rather than information, and fifteen pulsing icons is a light show. The
    /// second half of that is right and the first half wasn't: the fix is to
    /// give each glyph the motion its own measurement has, not to hold most of
    /// them still. A heart beats, a sun turns, a footprint wiggles, a ruler
    /// doesn't do much of anything and shouldn't pretend to.
    ///
    /// What keeps it off the disco floor is timing: the continuous effects go
    /// to the four things that genuinely never stop, and everything else moves
    /// on a long period, offset per tile, so no two glyphs ever move together.
    var motion: GlyphMotion = .periodicBounce
    /// SF Symbol for the tile. Kept here rather than in the view so a metric
    /// stays one entry — the grid, the charts and the picker all read from it.
    let symbol: String
    let value: (HealthSnapshot) -> Double?

    static func == (a: MetricSpec, b: MetricSpec) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// The name to use in a sentence.
    var spoken: String { phrase ?? label.lowercased() }

    /// Formats a figure to this metric's own precision. Takes a bare number
    /// rather than a snapshot, because averages and totals over a window are
    /// figures nobody's day actually held.
    func format(_ v: Double) -> String {
        guard v.isFinite else { return "·" }
        if precision == 0 {
            return v >= 1000 ? MetricSpec.grouped(v) : String(Int(v.rounded()))
        }
        return String(format: "%.\(precision)f", v)
    }

    /// Formats for display, or nil when the day holds nothing.
    func display(_ s: HealthSnapshot) -> String? {
        guard let v = value(s), v.isFinite else { return nil }
        return format(v)
    }

    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: Int(v.rounded()))) ?? String(Int(v))
    }
}

enum Metrics {
    /// Sleep is stored in hours; zero means "no samples", not a measured night.
    private static func sleep(_ s: HealthSnapshot) -> Double? {
        guard let h = s.totalSleepHours, h > 0 else { return nil }
        return h
    }

    static let all: [MetricSpec] = [
        // — Physical activity —
        .init(id: "steps", label: "Steps", group: .activity, unit: "", precision: 0, cumulative: true, goal: .atLeast, motion: .periodicWiggle, symbol: "figure.walk") { $0.steps },
        .init(id: "distance", label: "Distance", group: .activity, unit: "km", precision: 2, cumulative: true, phrase: "walking and running distance", goal: .atLeast, motion: .periodicWiggle, symbol: "location") { $0.distanceKm },
        .init(id: "flights", label: "Flights", group: .activity, unit: "", precision: 0, cumulative: true, phrase: "flights climbed", goal: .atLeast, motion: .periodicBounce, symbol: "figure.stairs") { $0.flightsClimbed },
        .init(id: "active_energy", label: "Active energy", group: .activity, unit: "kcal", precision: 0, cumulative: true, goal: .atLeast, motion: .breathing, symbol: "flame") { $0.activeEnergyBurned },
        .init(id: "daylight", label: "Daylight", group: .activity, unit: "min", precision: 0, cumulative: true, phrase: "time in daylight", goal: .atLeast, motion: .periodicRotate, symbol: "sun.max") { $0.timeInDaylight },

        // — Mobility & gait —
        .init(id: "walking_speed", label: "Walking speed", group: .gait, unit: "km/h", precision: 2, phrase: "walking speed", goal: .atLeast, motion: .periodicWiggle, symbol: "speedometer") { $0.walkingSpeedKmh },
        .init(id: "steadiness", label: "Steadiness", group: .gait, unit: "%", precision: 0, phrase: "walking steadiness", goal: .atLeast, motion: .periodicWiggle, symbol: "figure.walk.motion") { $0.walkingSteadiness.map { $0 * 100 } },
        .init(id: "asymmetry", label: "Asymmetry", group: .gait, unit: "%", precision: 1, phrase: "walking asymmetry", goal: .atMost, motion: .periodicWiggle, symbol: "arrow.left.arrow.right") { $0.walkingAsymmetryPct.map { $0 * 100 } },
        .init(id: "step_length", label: "Step length", group: .gait, unit: "m", precision: 2, motion: .periodicBounce, symbol: "ruler") { $0.walkingStepLength },
        .init(id: "double_support", label: "Double support", group: .gait, unit: "%", precision: 1, phrase: "double support time", goal: .atMost, motion: .periodicWiggle, symbol: "shoeprints.fill") { $0.walkingDoubleSupportPct.map { $0 * 100 } },
        .init(id: "stair_speed", label: "Stair speed", group: .gait, unit: "m/s", precision: 2, phrase: "stair-climbing speed", goal: .atLeast, motion: .periodicBounce, symbol: "arrow.up.forward") { $0.stairAscentSpeed },

        // — Recovery & environment —
        .init(id: "sleep", label: "Sleep", group: .recovery, unit: "hrs", precision: 1, goal: .atLeast, motion: .breathing, symbol: "moon.stars", value: sleep),
        .init(id: "resting_hr", label: "Resting HR", group: .recovery, unit: "bpm", precision: 0, phrase: "resting heart rate", goal: .atMost, motion: .beat, symbol: "heart") { $0.restingHeartRate },
        .init(id: "mindful", label: "Mindfulness", group: .recovery, unit: "min", precision: 0, cumulative: true, phrase: "mindful minutes", goal: .atLeast, motion: .breathing, symbol: "brain.head.profile") { $0.mindfulSessionMins },
        .init(id: "audio", label: "Audio exposure", group: .recovery, unit: "dB", precision: 0, phrase: "headphone audio exposure", goal: .atMost, motion: .beat, symbol: "ear") { $0.headphoneAudioExposure },

        // — Metabolic —
        .init(id: "glucose", label: "Blood glucose", group: .metabolic, unit: "mg/dL", precision: 0, phrase: "blood glucose", goal: .atMost, motion: .beat, symbol: "drop") { $0.avgBloodGlucoseMgdl },
        .init(id: "carbs", label: "Carbohydrates", group: .metabolic, unit: "g", precision: 0, cumulative: true, goal: .atMost, motion: .periodicBounce, symbol: "fork.knife") { $0.dietaryCarbohydratesG },
        .init(id: "insulin", label: "Insulin", group: .metabolic, unit: "IU", precision: 1, cumulative: true, motion: .periodicBounce, symbol: "syringe") { $0.insulinDeliveryIu },
    ]

    static func inGroup(_ g: MetricSpec.Group) -> [MetricSpec] {
        all.filter { $0.group == g }
    }

    static func by(id: String) -> MetricSpec? { all.first { $0.id == id } }

    /// Groups that actually have a reading today — an empty section is noise.
    static func populatedGroups(_ s: HealthSnapshot?) -> [MetricSpec.Group] {
        guard let s else { return [] }
        return MetricSpec.Group.allCases.filter { g in
            inGroup(g).contains { $0.value(s) != nil }
        }
    }
}
