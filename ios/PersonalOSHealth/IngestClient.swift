import Foundation
import UIKit

struct IngestPayload: Encodable {
    let provider: String
    let samples: [CanonicalSample]
    let timeZone: String
    let cursor: String?
}

struct IngestResponse: Decodable {
    let success: Bool
    let inserted: Int?
    let updated: Int?
    let rejected: [Rejection]?
    let error: String?

    struct Rejection: Decodable {
        let index: Int
        let reason: String
    }
}

/// The one thing that can go wrong here that isn't the transport's to explain.
enum IngestError: LocalizedError {
    case decode

    var errorDescription: String? {
        switch self {
        case .decode: return "The sync finished but the reply made no sense"
        }
    }
}

/// Uploads health samples to Personal OS.
struct IngestClient {
    private let transport: Transport

    /// Sixty seconds: a thirty day backfill is several hundred samples a batch, and the default is
    /// tuned for a screen waiting on one answer.
    init(auth: AuthProvider = Auth.provider) {
        transport = Transport(auth: auth, timeout: 60)
    }

    /// Convex takes arguments as JSON, and `CanonicalSample` already encodes to exactly the object
    /// its validator expects, so the samples are round tripped through `Encodable` rather than
    /// rebuilt field by field here — one place for the shape instead of two that can drift apart.
    private func send(_ samples: [CanonicalSample], cursor: String?) async throws -> IngestResponse {
        let encoded = try JSONEncoder().encode(samples)
        guard let rows = try JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] else {
            throw IngestError.decode
        }

        var args: [String: Any] = [
            "provider": AppConfig.provider,
            "samples": rows,
            // so the day a 23:30 walk lands on is today, not tomorrow in UTC
            "timeZone": TimeZone.current.identifier,
        ]
        if let cursor { args["cursor"] = cursor }

        let data = try await transport.mutation("health/samples:ingest", args)

        // The mutation answers with the counts alone; there is no envelope to report success
        // separately, because a failure arrives as a thrown error rather than as a field.
        struct Written: Decodable {
            let inserted: Int
            let updated: Int
            let rejected: [IngestResponse.Rejection]?
        }
        guard let written = try? JSONDecoder().decode(Written.self, from: data) else {
            throw IngestError.decode
        }
        return IngestResponse(
            success: true,
            inserted: written.inserted,
            updated: written.updated,
            rejected: written.rejected,
            error: nil
        )
    }

    private var deviceName: String { UIDevice.current.model }

    /// Today's snapshot.
    @discardableResult
    func upload(snapshot: HealthSnapshot) async throws -> IngestResponse {
        let samples = CanonicalMapper.samples(from: snapshot, device: deviceName)
        guard !samples.isEmpty else {
            return IngestResponse(success: true, inserted: 0, updated: 0, rejected: nil, error: nil)
        }
        return try await send(samples, cursor: AppConfig.syncCursor)
    }

    /// Historical backfill.
    func uploadHistory(snapshots: [HealthSnapshot]) async throws -> (inserted: Int, updated: Int) {
        let all = snapshots.flatMap { CanonicalMapper.samples(from: $0, device: deviceName) }

        var inserted = 0
        var updated = 0
        let batchSize = 500

        for start in stride(from: 0, to: all.count, by: batchSize) {
            let batch = Array(all[start..<min(start + batchSize, all.count)])
            let response = try await send(batch, cursor: nil)
            inserted += response.inserted ?? 0
            updated += response.updated ?? 0
        }

        return (inserted, updated)
    }
}
