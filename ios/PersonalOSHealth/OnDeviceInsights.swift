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

    static let experts: [(key: String, label: String, persona: String)] = [
        ("general", "Health architect", "Senior Principal Health Architect"),
        ("endocrinologist", "Endocrinologist", "Senior Endocrinologist"),
        ("nutritionist", "Nutritionist", "Senior Nutritionist"),
        ("strength_coach", "Strength coach", "Senior Strength Coach"),
        ("data_scientist", "Data scientist", "Senior Data Scientist"),
    ]

    static func persona(for expert: String) -> String {
        experts.first { $0.key == expert }?.persona ?? "Senior Data Scientist"
    }

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
    static func canReport(snapshots: [HealthSnapshot]) -> Bool {
        let withData = snapshots.filter { snap in
            Metrics.all.contains { $0.value(snap) != nil }
        }
        guard withData.count >= 3 else { return false }

        // Three distinct metrics, each present on at least two days — enough
        // for three observations about different pairs without reaching.
        let usable = Metrics.all.filter { spec in
            withData.filter { spec.value($0) != nil }.count >= 2
        }
        return usable.count >= 3
    }

    static func report(snapshots: [HealthSnapshot], expert: String, rangeLabel: String) -> String {
        let rows = snapshots.compactMap { snap -> String? in
            let parts = Metrics.all.compactMap { spec -> String? in
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

        Write exactly 3 observations, each about a different pair of measurements.

        Every observation is exactly three sentences:
        Sentence 1 names which two measurements moved together.
        Sentence 2 quotes two dates with the numbers for both measurements.
        Sentence 3 says what that might mean for you.

        For tone only, here is an observation written for a DIFFERENT person whose
        numbers are not above. Do not repeat it and do not use its numbers:

        "Your daylight time moved with your stair speed. On 04 Mar you spent 92 \
        minutes outside and climbed at 0.51 m/s, against 11 minutes and 0.38 m/s \
        on 06 Mar. Time outdoors looks connected to how briskly you took stairs."

        Begin.
        """
    }

    /// Meal suggestions, from the same local data.
    static func meals(snapshots: [HealthSnapshot], context: String) -> String {
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

        return """
        Recent metabolic and activity signals:
        \(lines.isEmpty ? "· no recent readings" : lines.joined(separator: "\n"))

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
    - Suggest ordinary food a person can actually buy and cook.
    - Never name a medical condition. Never mention medication or supplements.
    - Never write an introduction. Your first word begins the first suggestion.
    """
}
