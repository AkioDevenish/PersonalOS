import Foundation
import FoundationModels

/// Insights generated on the phone, by the phone.
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
                    // The on-device context is far smaller than a hosted model's, so a long window
                    // genuinely won't fit.
                    return "That's more history than the on-device model can hold at once. Try a shorter range, or switch to a hosted model."
                case .assetsUnavailable:
                    return "Apple Intelligence is still downloading. Try again shortly."
                case .guardrailViolation, .refusal:
                    // Health telemetry can read as medical content to a safety filter.
                    return "The on-device model declined to answer this one. Health readings sometimes trip its safety filter. A hosted model will usually handle it."
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
enum InsightPrompts {

    /// The four specialists, each with the measurements they read and the question they are the
    /// right person to answer.
    struct Expert {
        let key: String
        let label: String
        let persona: String
        /// Which measurements this one reads.
        let metrics: [String]
        /// The request itself, in that specialist's terms.
        let asks: String
        /// A worked observation in that voice.
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
            End each with a change in ordinary food or timing, never a supplement, \
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
            and 5.6 km/h after 07 Mar. That is a fatigue signal, not a fitness one, so \
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
            different pair. Quantify every claim: how much, over how many days. For \
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
    static func instructions(for expert: String) -> String {
        """
        You are a \(persona(for: expert)) reading one person's health measurements.

        Rules:
        - Address them as "you". Never write "the individual" or "the user".
        - Every observation must quote at least two real numbers from their data.
        - If the numbers do not support a claim, do not make the claim.
        - Never name a medical condition. Never mention medication.
        - Write plain sentences. Never use #, *, or bullet characters.
        - Never use a long dash. A comma or a full stop instead.
        - Never write an introduction. Your first word begins the first observation.
        """
    }

    /// The data half: a compact table the model can actually read.
    static func canReport(snapshots: [HealthSnapshot], expert: String) -> Bool {
        let e = self.expert(expert)
        let specs = e.metrics.isEmpty ? Metrics.all : e.metrics.compactMap { Metrics.by(id: $0) }

        let withData = snapshots.filter { snap in
            specs.contains { $0.value(snap) != nil }
        }
        guard withData.count >= 3 else { return false }

        // Three distinct metrics, each present on at least two days — enough for three observations
        // about different pairs without reaching.
        let usable = specs.filter { spec in
            withData.filter { spec.value($0) != nil }.count >= 2
        }
        return usable.count >= 3
    }

    /// The specialist's own request, over the measurements that specialist reads.
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
            return "\(day): \(parts.joined(separator: ", "))"
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
    static func meals(
        snapshots: [HealthSnapshot],
        context: String,
        country: String,
        dishes: [String]
    ) -> String {
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

        var place = ""
        if !(country == "Anywhere" || country.isEmpty) {
            place = """


            I cook and shop in \(country). Suggest dishes eaten there, using \
            ingredients sold there. Do not suggest anything I would have to import.
            """
        }

        // The list is the whole point.
        if !dishes.isEmpty {
            place += """


            These are dishes people actually eat in \(country):
            \(dishes.map { "· \($0)" }.joined(separator: "\n"))

            Pick from that list. Use the name exactly as written above. Only go \
            outside it if nothing on it suits the readings, and say so if you do.
            """
        } else if !place.isEmpty {
            // Nobody has named anything for this country yet, so the model has only its own recall
            // to go on — which is the thing that put bunny chow in Trinidad's list.
            place += """


            Nobody has told us what is eaten in \(country) yet. Do not name a \
            local dish unless you are certain of it. Describe the food instead \
            — what it is made of and how it is cooked — using ingredients sold \
            there. A plain description is better than a name you are unsure of.
            """
        }

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
    - Never use a long dash. A comma or a full stop instead.
    """
}
