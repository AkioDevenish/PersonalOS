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

enum IngestError: LocalizedError {
    case invalidURL
    case notSignedIn
    case http(Int, String)
    case decode

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .notSignedIn: return "Sign in to sync your health data"
        case .http(let code, let body):
            if code == 401 { return "Your session expired. Sign in again" }
            return "HTTP \(code): \(body)"
        case .decode: return "Unexpected server response"
        }
    }
}

/// Uploads health samples to Personal OS.
///
/// Identity comes from the signed-in user's Clerk token and nothing else. The
/// previous version sent an `x-personal-os-user-id` header alongside a shared
/// secret, which meant the phone declared whose data it was writing — anyone
/// with the secret could write into any account. There is now no way to name a
/// user: whoever the token belongs to is whose ledger this lands in.
struct IngestClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) {
        self.auth = auth
    }

    private var deviceName: String {
        UIDevice.current.model
    }

    private func makeRequest(url: URL, body: Data) async throws -> URLRequest {
        guard let token = await auth.currentToken() else {
            throw IngestError.notSignedIn
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        request.httpBody = body
        return request
    }

    private func endpoint() throws -> URL {
        guard let base = URL(string: AppConfig.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw IngestError.invalidURL
        }
        return base.appendingPathComponent(AppConfig.ingestPath)
    }

    private func send(_ samples: [CanonicalSample], cursor: String?) async throws -> IngestResponse {
        let payload = IngestPayload(
            provider: AppConfig.provider,
            samples: samples,
            // so the server buckets a 23:30 walk on today, not tomorrow in UTC
            timeZone: TimeZone.current.identifier,
            cursor: cursor
        )

        let request = try await makeRequest(
            url: try endpoint(),
            body: try JSONEncoder().encode(payload)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IngestError.decode }

        guard (200...299).contains(http.statusCode) else {
            throw IngestError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let decoded = try? JSONDecoder().decode(IngestResponse.self, from: data) else {
            throw IngestError.decode
        }
        return decoded
    }

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
    ///
    /// Batches by sample rather than by day: the server caps a request at 1000
    /// samples, and one day now yields up to ~19 of them, so counting days
    /// would overshoot. Re-sending is harmless — ingest upserts on
    /// (user, provider, metric, recorded_at) — so a partial run can simply be
    /// repeated.
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
