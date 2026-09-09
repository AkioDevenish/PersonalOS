import Foundation

/// The directory of people you can ask, and the way onto it.
struct SpecialistsClient {
    private let transport: Transport

    init(auth: AuthProvider = Auth.provider) { transport = Transport(auth: auth) }

    struct Specialist: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let country: String
        let credentials: String
        let bio: String
        let specialties: [String]
        let offers_video: Bool
        let price_credits: Int

        /// Whether talking to this person costs anything at all.
        var free: Bool { price_credits == 0 }

        /// The country in words, which is what someone wants to know before
        /// asking about food or exercise.
        var place: String { Cuisine.name(for: country) }

        var price: String {
            price_credits == 0
                ? "Free"
                : "\(price_credits) \(price_credits == 1 ? "credit" : "credits")"
        }
    }

    /// The caller's own application, for the handful of people who have one.
    struct Application: Decodable, Hashable {
        let name: String
        let country: String
        let credentials: String
        let bio: String
        let specialties: [String]
        let offers_video: Bool
        let price_credits: Int
        let active: Bool
        let status: String          // pending | approved | declined

        var approved: Bool { status == "approved" }
        var pending: Bool { status == "pending" }
        var declined: Bool { status == "declined" }
    }

    struct Desk: Decodable {
        let specialists: [Specialist]
        let application: Application?

        static let empty = Desk(specialists: [], application: nil)
    }

    func desk() async throws -> Desk {
        let data = try await transport.send("/api/well-being/specialists", method: "GET", body: nil)
        return try JSONDecoder().decode(Desk.self, from: data)
    }

    /// Applies to appear, or edits an application already made.
    @discardableResult
    func apply(
        name: String,
        country: String,
        credentials: String,
        bio: String,
        specialties: [String],
        offersVideo: Bool,
        priceCredits: Int,
        active: Bool
    ) async throws -> String {
        struct Result: Decodable { let status: String }
        let data = try await transport.send(
            "/api/well-being/specialists", method: "POST",
            body: [
                "name": name,
                "country": country,
                "credentials": credentials,
                "bio": bio,
                "specialties": specialties,
                "offers_video": offersVideo,
                "price_credits": priceCredits,
                "active": active,
            ]
        )
        return (try? JSONDecoder().decode(Result.self, from: data))?.status ?? "pending"
    }
}
