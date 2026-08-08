import Foundation
import FoundationModels

/// Insights generated on the phone, by the phone.
///
/// This is the only engine in the app that needs nothing: no API key, no
/// account with a model vendor, no Mac awake on the same network, no internet.
/// A person installs the app, signs in, and their first report works. Every
/// other provider asks them to go and get a credential first, which is a fine
/// ask for someone who already has one and a wall for everyone else.
///
/// It matters more than convenience here. A hosted report means posting
/// someone's glucose, sleep and heart data to a third party. On-device, the
/// numbers never leave the phone — the model is already there, and the prompt
/// is built from HealthKit data the app has read locally.
///
/// The tradeoff is real and worth stating plainly: this is a roughly 3-billion
/// parameter model. It writes a decent read of a week. It is not Claude
/// examining a quarter of correlations. The app offers it as the default that
/// always works, not as the best available.
@available(iOS 26.0, *)
enum OnDeviceInsights {

    // MARK: Availability

    enum Availability: Equatable {
        case ready
        /// The hardware can't run it — no amount of settings-changing helps.
        case unsupportedDevice
        /// Apple Intelligence is off in Settings; the user can fix this.
        case notEnabled
        /// Downloading or warming up; worth trying again shortly.
        case preparing

        var isReady: Bool { self == .ready }

        /// Written for someone who does not know what a foundation model is.
        var explanation: String {
            switch self {
            case .ready:
                return "Runs on this iPhone. Nothing leaves the device."
            case .unsupportedDevice:
                return "This iPhone can't run on-device intelligence. Choose a hosted model instead."
            case .notEnabled:
                return "Turn on Apple Intelligence in Settings to use this."
            case .preparing:
                return "Apple Intelligence is still getting ready. Try again in a few minutes."
            }
        }
    }

    static var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unsupportedDevice
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .preparing
            @unknown default: return .preparing
            }
        @unknown default:
            return .preparing
        }
    }

    // MARK: Generation

    /// Runs a prompt through the on-device model.
    ///
    /// `instructions` are the persona and the rules; they are separated from
    /// the prompt because the framework treats them as more trustworthy than
    /// prompt text, which is the right place for "you are an endocrinologist,
    /// never diagnose".
    static func generate(
        instructions: String,
        prompt: String,
        temperature: Double = 0.3
    ) async throws -> String {
        guard availability.isReady else {
            throw OnDeviceError.unavailable(availability)
        }

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: temperature)
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw OnDeviceError.empty }
            return text
        } catch let error as LanguageModelSession.GenerationError {
            throw OnDeviceError.generation(error)
        }
    }

    enum OnDeviceError: LocalizedError {
        case unavailable(Availability)
        case generation(LanguageModelSession.GenerationError)
        case empty
        case notEnoughData

        var errorDescription: String? {
            switch self {
            case .unavailable(let a):
                return a.explanation
            case .notEnoughData:
                return "Not enough recorded days yet to draw a pattern from. Wear your watch for a few more days, or widen the range."
            case .empty:
                return "The on-device model returned nothing. Try again."
            case .generation(let e):
                switch e {
                case .exceededContextWindowSize:
                    // The on-device context is far smaller than a hosted
                    // model's, so a long window genuinely won't fit.
                    return "That's more history than the on-device model can hold at once. Try a shorter range, or switch to a hosted model."
                case .assetsUnavailable:
                    return "Apple Intelligence is still downloading. Try again shortly."
                case .guardrailViolation, .refusal:
                    // Health telemetry can read as medical content to a safety
                    // filter. Say what happened rather than showing a failure.
                    return "The on-device model declined to answer this one — health readings sometimes trip its safety filter. A hosted model will usually handle it."
                case .rateLimited, .concurrentRequests:
                    return "The on-device model is busy. Try again in a moment."
                case .unsupportedLanguageOrLocale:
                    return "The on-device model doesn't support this language yet."
                default:
                    return "The on-device model couldn't complete this. Try again, or switch models."
                }
            }
        }
    }
}

// MARK: - Prompts

/// Turns HealthKit snapshots into the prompts the insight views ask for.
///
/// Deliberately mirrors the personas and the tag vocabulary the server's
/// analyze route uses, so a report written on the phone reads like one written
/// by Claude — same shape, same constraints, same refusal to diagnose. Only
/// the engine differs.
enum InsightPrompts {

    /// The four specialists, each with the measurements they read and the
    /// question they are the right person to answer.
    ///
    /// "Health architect" used to head this list and is gone. It was allowed
    /// every finding the other four were, so its report was their union and
    /// read as none of them — and having "all of the above" first made the
    /// real specialists look like filters on one report rather than four
    /// different readings.
    struct Expert {
        let key: String
        let label: String
        let persona: String
        /// Which measurements this one reads. The prompt is built from these,
        /// so a strength coach is handed gait and load, and an endocrinologist
        /// is handed glucose and sleep timing — they are not looking at the
        /// same table and calling it a different job.
        let metrics: [String]
        /// The request itself, in that specialist's terms.
        let asks: String
        /// A worked observation in that voice. Belongs to a fictional other
        /// person, and uses metrics the real table won't contain, because an
        /// earlier version's example came back verbatim as observation one.
        let example: String
    }

    static let experts: [Expert] = [
        Expert(
            key: "endocrinologist",
            label: "Endocrinologist",
            persona: "Senior Endocrinologist",
            metrics: ["glucose", "carbs", "insulin", "sleep", "resting_hr", "active_energy"],
            asks: """
            Write 3 observations about your metabolic and circadian picture. Look at \
            glucose level and how much it varies, carbohydrates against glucose, and \
            sleep length against resting heart rate. How regular the timing is counts \
            as much as the amounts.
            """,
            example: """
            "Your glucose sat highest on the nights you slept least. On 04 Mar you \
            slept 5.4 hours and averaged 118 mg/dL, against 7.9 hours and 96 mg/dL on \
            07 Mar. Short nights look like the thing moving your morning readings."
            """
        ),
        Expert(
            key: "nutritionist",
            label: "Nutritionist",
            persona: "Senior Nutritionist",
            metrics: ["carbs", "glucose", "active_energy", "basal_energy", "sleep", "steps"],
            asks: """
            Write 3 observations about what your eating appears to be doing. Work \
            forward from carbohydrates to glucose, energy and the next day's activity. \
            End each with a change in ordinary food or timing — never a supplement, \
            never a named diet.
            """,
            example: """
            "Your heaviest carbohydrate days were followed by your quietest ones. On \
            04 Mar you took 310 g and walked 4,100 steps the next day, against 180 g \
            and 9,600 steps after 07 Mar. Moving some of that intake earlier in the \
            day is worth a week's trial."
            """
        ),
        Expert(
            key: "strength_coach",
            label: "Strength coach",
            persona: "Senior Strength Coach",
            metrics: ["active_energy", "steps", "flights", "sleep", "resting_hr",
                      "walking_speed", "steadiness", "asymmetry", "double_support", "stair_speed"],
            asks: """
            Write 3 observations about load and readiness. Read activity and energy \
            against sleep, resting heart rate and the gait measures. Say plainly \
            whether this is a week to push or a week to back off, and what the next \
            session should be.
            """,
            example: """
            "Your walking speed dropped on the days after your hardest ones. On 04 Mar \
            you burned 890 kcal and walked at 4.9 km/h the next day, against 410 kcal \
            and 5.6 km/h after 07 Mar. That is a fatigue signal, not a fitness one — \
            keep the next session easy."
            """
        ),
        Expert(
            key: "data_scientist",
            label: "Data scientist",
            persona: "Senior Data Scientist",
            metrics: [],   // empty means the whole table; correlation is the job
            asks: """
            Write 3 observations about relationships between measurements, each about a \
            different pair. Quantify every claim — how much, over how many days. For \
            each, name the other explanation the same numbers would fit, and say which \
            of the two this data cannot separate.
            """,
            example: """
            "Your daylight time moved with your stair speed across 9 of 12 days. On \
            04 Mar you spent 92 minutes outside and climbed at 0.51 m/s, against 11 \
            minutes and 0.38 m/s on 06 Mar. Both also track the weekend, which this \
            window is too short to rule out."
            """
        ),
    ]

    static func expert(_ key: String) -> Expert {
        experts.first { $0.key == key } ?? experts[experts.count - 1]
    }

    static func persona(for expert: String) -> String { self.expert(expert).persona }

    /// The system half: who the model is and what it may not do.
    ///
    /// Every line here was earned by watching the on-device model ignore a
    /// vaguer one. It is a ~3B model: it follows a few concrete rules well and
    /// many abstract ones badly, so each is a single checkable instruction
    /// rather than a principle. "Never use #, *, or bullet characters" holds
    /// where "no markdown headers" did not.
    static func instructions(for expert: String) -> String {
        """
        You are a \(persona(for: expert)) reading one person's health measurements.

        Rules:
        - Address them as "you". Never write "the individual" or "the user".
        - Every observation must quote at least two real numbers from their data.
        - If the numbers do not support a claim, do not make the claim.
        - Never name a medical condition. Never mention medication.
        - Write plain sentences. Never use #, *, or bullet characters.
        - Never write an introduction. Your first word begins the first observation.
        """
    }

    /// The data half: a compact table the model can actually read.
    ///
    /// Only metrics with a reading are included. Empty columns spend context
    /// the on-device model does not have to spare, and invite the model to
    /// comment on absent data as though it were a finding.
    ///
    /// The sentence-by-sentence structure is not fussiness. Asked for "a short
    /// paragraph and a hypothesis" this model produced markdown headers it had
    /// been told not to use and, worse, two observations that contradicted each
    /// other. Given three numbered sentences to fill it stays inside the data.
    ///
    /// The worked example belongs to a fictional other person and uses metrics
    /// that appear nowhere in the real data, because an earlier version using
    /// the same shape was copied back verbatim as the first observation.
    /// Whether there is enough here to ask for three paired observations.
    ///
    /// This guard is the most important thing in the file. Handed two days of
    /// step counts and asked for three observations about pairs of
    /// measurements, the on-device model invented the missing half: it reported
    /// stair-climbing speeds of 0.12 and 0.24 m/s that appear nowhere in the
    /// input, as though they were readings. Fabricated numbers presented to
    /// someone as their own health data are worse than no report at all, and a
    /// person might act on them.
    ///
    /// No prompt rule reliably stops a model this size filling a gap it has
    /// been asked to fill. So the gap is never presented: unless the data can
    /// support the question, the question is not asked.
    /// Asked per specialist, because each reads its own columns. An
    /// endocrinologist with a fortnight of step counts and no glucose has
    /// nothing to read, however full the table looks overall — and a model
    /// asked about glucose anyway will supply some.
    static func canReport(snapshots: [HealthSnapshot], expert: String) -> Bool {
        let e = self.expert(expert)
        let specs = e.metrics.isEmpty ? Metrics.all : e.metrics.compactMap { Metrics.by(id: $0) }

        let withData = snapshots.filter { snap in
            specs.contains { $0.value(snap) != nil }
        }
        guard withData.count >= 3 else { return false }

        // Three distinct metrics, each present on at least two days — enough
        // for three observations about different pairs without reaching.
        let usable = specs.filter { spec in
            withData.filter { spec.value($0) != nil }.count >= 2
        }
        return usable.count >= 3
    }

    /// The specialist's own request, over the measurements that specialist reads.
    ///
    /// This used to take `expert` and never use it: every specialist was handed
    /// the whole table and the identical instruction to find three pairs that
    /// moved together. The persona was one line of the system prompt over an
    /// otherwise identical request, and a ~3B model given the same question
    /// four times answers it the same way four times — which is exactly what a
    /// reader sees when the endocrinologist and the strength coach hand back
    /// the same report under different headings.
    ///
    /// Now the lens is in the data as well as the words: each specialist gets
    /// their own columns, their own question and their own worked example. The
    /// data scientist keeps the whole table, because relating everything to
    /// everything is that one's actual job.
    static func report(snapshots: [HealthSnapshot], expert: String, rangeLabel: String) -> String {
        let e = self.expert(expert)
        let specs = e.metrics.isEmpty
            ? Metrics.all
            : e.metrics.compactMap { Metrics.by(id: $0) }

        let rows = snapshots.compactMap { snap -> String? in
            let parts = specs.compactMap { spec -> String? in
                guard let shown = spec.display(snap) else { return nil }
                return "\(spec.label) \(shown)\(spec.unit.isEmpty ? "" : " " + spec.unit)"
            }
            guard !parts.isEmpty else { return nil }
            let day = snap.recordedAt.formatted(.dateTime.day().month(.abbreviated))
            return "\(day) — \(parts.joined(separator: ", "))"
        }

        return """
        Here are your measurements for \(rangeLabel).

        \(rows.joined(separator: "\n"))

        \(e.asks)

        Every observation is exactly three sentences:
        Sentence 1 names which measurements you are reading together.
        Sentence 2 quotes two dates with the numbers for both.
        Sentence 3 says what that means for you, as a \(e.persona.lowercased()) would put it.

        For tone only, here is an observation written for a DIFFERENT person whose
        numbers are not above. Do not repeat it and do not use its numbers:

        \(e.example)

        Begin.
        """
    }

    /// Meal suggestions, from the same local data, cooked where you live.
    ///
    /// The country is not decoration. Without it a model reaches for the same
    /// handful of Californian wellness food every time — and a suggestion you
    /// cannot buy the ingredients for is not a suggestion. Named twice on
    /// purpose: once as the place, once as the constraint, because a 3B model
    /// will drop a single mention by the third meal.
    static func meals(snapshots: [HealthSnapshot], context: String, country: String) -> String {
        let recent = snapshots.suffix(7)
        let lines = recent.compactMap { snap -> String? in
            let keys = ["glucose", "carbs", "sleep", "active_energy", "steps"]
            let parts = keys.compactMap { id -> String? in
                guard let spec = Metrics.by(id: id), let shown = spec.display(snap) else { return nil }
                return "\(spec.label) \(shown)\(spec.unit.isEmpty ? "" : spec.unit)"
            }
            guard !parts.isEmpty else { return nil }
            return "· " + parts.joined(separator: ", ")
        }

        let place = country == "Anywhere" || country.isEmpty
            ? ""
            : """


        I cook and shop in \(country). Suggest dishes eaten there, using \
        ingredients sold there. Do not suggest anything I would have to import.
        """

        return """
        Recent metabolic and activity signals:
        \(lines.isEmpty ? "· no recent readings" : lines.joined(separator: "\n"))\(place)

        Suggest 3 options for \(context). For each:
        **Name:** <name>
        **Why:** <one sentence tied to the readings above>
        **Macros:** <approximate calories | protein | carbs | fat>
        **Prep:** <one or two sentences>

        Then one final line:
        [NUTRITION_INSIGHT] <a single sentence about the current pattern>
        """
    }

    static let mealInstructions = """
    You are a Senior Nutritionist suggesting meals from someone's health measurements.

    Rules:
    - Address them as "you".
    - Suggest ordinary food a person can actually buy and cook where they live.
    - If they name a country, every suggestion is food eaten in that country.
    - Never name a medical condition. Never mention medication or supplements.
    - Never write an introduction. Your first word begins the first suggestion.
    """
}
