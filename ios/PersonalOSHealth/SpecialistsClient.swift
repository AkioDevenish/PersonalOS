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
        /// Whole minor units of `currency`. Zero means free.
        let price_minor: Int
        let currency: String

        /// Whether talking to this person costs anything at all.
        var free: Bool { price_minor == 0 }

        /// The country in words, which is what someone wants to know before
        /// asking about food or exercise.
        var place: String { Cuisine.name(for: country) }

        var price: String {
            free ? "Free" : Money.text(price_minor, currency)
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
        let price_minor: Int
        let currency: String
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

    /// Two calls rather than one route returning both, which is what the
    /// forwarding layer was doing on the phone's behalf.
    func desk() async throws -> Desk {
        async let listing = transport.query("health/consult:directory")
        async let mine = transport.query("health/consult:myApplication")

        let specialists = try JSONDecoder().decode([Specialist].self, from: try await listing)
        let application = try? JSONDecoder().decode(Application.self, from: try await mine)
        return Desk(specialists: specialists, application: application)
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
        priceMinor: Int,
        currency: String,
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
                "price_minor": priceMinor,
                "currency": currency,
                "active": active,
        ]
        // Omitted rather than sent as null when unchanged, so editing a bio
        // cannot silently drop a photograph already uploaded.
        if let photo { body["photo"] = photo }
        let data = try await transport.mutation("health/consult:apply", body)
        return (try? JSONDecoder().decode(Result.self, from: data))?.status ?? "pending"
    }

    /// One consultation waiting on the practitioner reading this.
    struct Consultation: Decodable, Identifiable, Hashable {
        let id: String
        let topic: String
        let kind: String
        let status: String
        let payment_status: String
        let created_at: Double
        let updated_at: Double
        let replies: Int
        let last_message: String
        /// Whether the ball is in the practitioner's court.
        let needs_reply: Bool

        var asked: Date { Date(timeIntervalSince1970: created_at / 1000) }
        var isCall: Bool { kind == "video" }
        var unpaid: Bool { payment_status == "pending" }
    }

    /// The practitioner's own queue. Throws when the caller is not listed.
    func queue() async throws -> [Consultation] {
        let data = try await transport.query("health/consult:queue")
        return try JSONDecoder().decode([Consultation].self, from: data)
    }

    /// Sends a photograph to storage and returns its id.
    ///
    /// Two steps on purpose. The route hands back a one-time URL and the image
    /// goes straight from the phone to Convex, so several megabytes of JPEG
    /// never pass through a JSON body.
    func uploadPhoto(_ jpeg: Data) async throws -> String {
        struct Stored: Decodable { let storageId: String }

        // The mutation answers with the URL itself, as a bare JSON string.
        let slot = try await transport.mutation("health/consult:photoUploadUrl")
        guard let link = try? JSONDecoder().decode(String.self, from: slot),
              let target = URL(string: link) else {
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
