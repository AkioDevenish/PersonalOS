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
        let photo_url: String?
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
        let photo_url: String?
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
        photo: String?,
        priceCredits: Int,
        active: Bool
    ) async throws -> String {
        struct Result: Decodable { let status: String }
        var body: [String: Any] = [
                "name": name,
                "country": country,
                "credentials": credentials,
                "bio": bio,
                "specialties": specialties,
                "offers_video": offersVideo,
                "price_credits": priceCredits,
                "active": active,
        ]
        // Omitted rather than sent as null when unchanged, so editing a bio
        // cannot silently drop a photograph already uploaded.
        if let photo { body["photo"] = photo }
        let data = try await transport.send(
            "/api/well-being/specialists", method: "POST", body: body
        )
        return (try? JSONDecoder().decode(Result.self, from: data))?.status ?? "pending"
    }

    /// Sends a photograph to storage and returns its id.
    ///
    /// Two steps on purpose. The route hands back a one-time URL and the image
    /// goes straight from the phone to Convex, so several megabytes of JPEG
    /// never pass through a JSON body.
    func uploadPhoto(_ jpeg: Data) async throws -> String {
        struct Slot: Decodable { let url: String }
        struct Stored: Decodable { let storageId: String }

        let slot = try await transport.send("/api/well-being/specialists", method: "PUT", body: nil)
        guard let target = URL(string: (try JSONDecoder().decode(Slot.self, from: slot)).url) else {
            throw TransportError.badURL
        }

        var upload = URLRequest(url: target)
        upload.httpMethod = "POST"
        upload.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        upload.httpBody = jpeg

        let (data, response) = try await URLSession.shared.data(for: upload)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TransportError.badResponse
        }
        return try JSONDecoder().decode(Stored.self, from: data).storageId
    }
}
