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

/// Turns HealthKit snapshots into the meal prompt.
enum InsightPrompts {

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
