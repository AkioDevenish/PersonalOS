import Foundation

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
    /// SF Symbol for the tile. Kept here rather than in the view so a metric
    /// stays one entry — the grid, the charts and the picker all read from it.
    let symbol: String
    let value: (HealthSnapshot) -> Double?

    static func == (a: MetricSpec, b: MetricSpec) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// Formats a figure to this metric's own precision. Takes a bare number
    /// rather than a snapshot, because averages and totals over a window are
    /// figures nobody's day actually held.
    func format(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
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
        .init(id: "steps", label: "Steps", group: .activity, unit: "", precision: 0, cumulative: true, symbol: "figure.walk") { $0.steps },
        .init(id: "distance", label: "Distance", group: .activity, unit: "km", precision: 2, cumulative: true, symbol: "location") { $0.distanceKm },
        .init(id: "flights", label: "Flights", group: .activity, unit: "", precision: 0, cumulative: true, symbol: "figure.stairs") { $0.flightsClimbed },
        .init(id: "active_energy", label: "Active energy", group: .activity, unit: "kcal", precision: 0, cumulative: true, symbol: "flame") { $0.activeEnergyBurned },
        .init(id: "basal_energy", label: "Basal energy", group: .activity, unit: "kcal", precision: 0, cumulative: true, symbol: "bolt") { $0.basalEnergyBurned },
        .init(id: "daylight", label: "Daylight", group: .activity, unit: "min", precision: 0, cumulative: true, symbol: "sun.max") { $0.timeInDaylight },

        // — Mobility & gait —
        .init(id: "walking_speed", label: "Walking speed", group: .gait, unit: "km/h", precision: 2, symbol: "speedometer") { $0.walkingSpeedKmh },
        .init(id: "steadiness", label: "Steadiness", group: .gait, unit: "%", precision: 0, symbol: "figure.walk.motion") { $0.walkingSteadiness.map { $0 * 100 } },
        .init(id: "asymmetry", label: "Asymmetry", group: .gait, unit: "%", precision: 1, symbol: "arrow.left.arrow.right") { $0.walkingAsymmetryPct.map { $0 * 100 } },
        .init(id: "step_length", label: "Step length", group: .gait, unit: "m", precision: 2, symbol: "ruler") { $0.walkingStepLength },
        .init(id: "double_support", label: "Double support", group: .gait, unit: "%", precision: 1, symbol: "shoeprints.fill") { $0.walkingDoubleSupportPct.map { $0 * 100 } },
        .init(id: "stair_speed", label: "Stair speed", group: .gait, unit: "m/s", precision: 2, symbol: "arrow.up.forward") { $0.stairAscentSpeed },

        // — Recovery & environment —
        .init(id: "sleep", label: "Sleep", group: .recovery, unit: "hrs", precision: 1, symbol: "moon.stars", value: sleep),
        .init(id: "resting_hr", label: "Resting HR", group: .recovery, unit: "bpm", precision: 0, symbol: "heart") { $0.restingHeartRate },
        .init(id: "mindful", label: "Mindfulness", group: .recovery, unit: "min", precision: 0, cumulative: true, symbol: "brain.head.profile") { $0.mindfulSessionMins },
        .init(id: "audio", label: "Audio exposure", group: .recovery, unit: "dB", precision: 0, symbol: "ear") { $0.headphoneAudioExposure },

        // — Metabolic —
        .init(id: "glucose", label: "Blood glucose", group: .metabolic, unit: "mg/dL", precision: 0, symbol: "drop") { $0.avgBloodGlucoseMgdl },
        .init(id: "carbs", label: "Carbohydrates", group: .metabolic, unit: "g", precision: 0, cumulative: true, symbol: "fork.knife") { $0.dietaryCarbohydratesG },
        .init(id: "insulin", label: "Insulin", group: .metabolic, unit: "IU", precision: 1, cumulative: true, symbol: "syringe") { $0.insulinDeliveryIu },
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
