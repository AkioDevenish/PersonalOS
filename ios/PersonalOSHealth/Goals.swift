import SwiftUI

/// What you are trying to do, in numbers.
///
/// The briefing used to close with advice invented from thresholds this app
/// chose: under four thousand steps was "the day still owes you a walk",
/// because four thousand was a number in a source file. That is a guess about
/// a stranger. A goal is the same sentence with the guessing removed, and it
/// is the only part of the app the person, rather than the model, gets to
/// decide.
///
/// Kept on the phone rather than in Convex. A goal is small, personal, and
/// wanted offline — the briefing composes with no network, and it would be a
/// poor trade to have it lose your targets when the signal goes.
enum Goals {
    private static let key = "personal_os_goals"

    /// Metric id to target. Absent means no goal, which is different from a
    /// target of zero.
    static var all: [String: Double] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func target(_ id: String) -> Double? { all[id] }

    static func set(_ id: String, _ value: Double?) {
        var current = all
        if let value, value > 0 { current[id] = value } else { current.removeValue(forKey: id) }
        all = current
    }

    /// The metrics a goal can be set on, in the order the catalogue lists them.
    static var settable: [MetricSpec] { Metrics.all.filter { $0.goal.isSettable } }

    /// Sensible opening numbers, so the screen isn't a wall of empty fields.
    ///
    /// Offered, never applied: a suggestion you have to accept is a suggestion,
    /// and a number written in for you is this app deciding again.
    static func suggestion(for spec: MetricSpec) -> Double? {
        switch spec.id {
        case "steps":         return 8000
        case "sleep":         return 7.5
        case "active_energy": return 500
        case "daylight":      return 30
        case "mindful":       return 10
        case "flights":       return 10
        case "distance":      return 5
        case "resting_hr":    return 60
        case "glucose":       return 110
        default:              return nil
        }
    }

    // MARK: Reading the day against them

    struct Progress: Identifiable {
        let spec: MetricSpec
        let target: Double
        let actual: Double?

        var id: String { spec.id }

        var met: Bool {
            guard let actual else { return false }
            return spec.goal == .atMost ? actual <= target : actual >= target
        }

        /// How far short, in the metric's own units. Nil once it is met.
        var shortfall: Double? {
            guard !met else { return nil }
            guard let actual else { return target }
            return spec.goal == .atMost ? actual - target : target - actual
        }
    }

    /// Every goal, measured against a day. Unmet first, because those are the
    /// ones the closing list is for.
    static func progress(on snapshot: HealthSnapshot?) -> [Progress] {
        settable.compactMap { spec -> Progress? in
            guard let target = target(spec.id) else { return nil }
            return Progress(spec: spec, target: target, actual: snapshot.flatMap { spec.value($0) })
        }
        .sorted { a, b in
            if a.met != b.met { return !a.met }
            return a.spec.id < b.spec.id
        }
    }
}

/// Setting them.
struct GoalsView: View {
    @State private var values: [String: String] = [:]
    @FocusState private var editing: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Goals", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("What you're aiming at.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                    .flowIn(1)

                Text("Set as many or as few as you like. The morning briefing closes with whichever ones the day hasn't met yet, so an empty list here means it stops telling you what to do.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                ForEach(Array(groups.enumerated()), id: \.element.group) { i, section in
                    SectionRule(text: section.group.rawValue)
                        .padding(.top, i == 0 ? 34 : 30)
                        .flowIn(3 + i)

                    VStack(spacing: 0) {
                        ForEach(section.specs) { spec in
                            row(spec)
                        }
                    }
                    .padding(.top, 8)
                    .flowIn(3 + i)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .toolbarBackground(Theme.linen, for: .navigationBar)
        .onAppear(perform: read)
    }

    private var groups: [(group: MetricSpec.Group, specs: [MetricSpec])] {
        MetricSpec.Group.allCases.compactMap { group in
            let specs = Goals.settable.filter { $0.group == group }
            return specs.isEmpty ? nil : (group, specs)
        }
    }

    private func row(_ spec: MetricSpec) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(spec.label)
                    .font(Theme.serif(19))
                    .foregroundStyle(Theme.ink)
                // "At least" or "at most" is the whole meaning of the number
                // beside it, and it is not something a person should have to
                // infer from which metric it is.
                Text(spec.goal == .atMost ? "at most" : "at least")
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
            }

            Spacer()

            TextField(placeholder(spec), text: binding(for: spec))
                .font(Theme.serif(22))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($editing, equals: spec.id)
                .frame(maxWidth: 110)
                .onChange(of: values[spec.id] ?? "") { _, new in
                    Goals.set(spec.id, Double(new))
                }

            if !spec.unit.isEmpty {
                Text(spec.unit)
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
                    .frame(width: 34, alignment: .leading)
            } else {
                Color.clear.frame(width: 34, height: 1)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { editing = spec.id }
    }

    private func placeholder(_ spec: MetricSpec) -> String {
        Goals.suggestion(for: spec).map { spec.format($0) } ?? "none"
    }

    private func binding(for spec: MetricSpec) -> Binding<String> {
        Binding(
            get: { values[spec.id] ?? "" },
            set: { values[spec.id] = $0 }
        )
    }

    private func read() {
        let stored = Goals.all
        values = Dictionary(uniqueKeysWithValues: Goals.settable.compactMap { spec in
            stored[spec.id].map { (spec.id, spec.format($0)) }
        })
    }
}
