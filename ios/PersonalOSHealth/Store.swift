import Foundation
import StoreKit

/// Purchases, and what they entitle you to.
///
/// Two rules shape this file.
///
/// First, the phone never decides what someone has paid for. StoreKit will
/// happily tell the app a transaction is verified, and that answer is worth
/// having — but it is an answer from a device an attacker may control. Every
/// transaction is forwarded to the server, which checks Apple's signature on
/// it before granting anything, and the entitlement the app displays is read
/// back from the server. `Transaction.currentEntitlements` is used to know
/// what to *send*, never to unlock.
///
/// Second, transactions can arrive at any time — a renewal, a purchase made on
/// another device, an interrupted flow that completes later, an Ask-to-Buy
/// approval days after the fact. That's what the listener is for, and why it
/// starts at launch rather than when a paywall opens.
/// `@Observable` rather than `ObservableObject`: the synthesized
/// `objectWillChange` cannot be produced for a `@MainActor`-isolated class, and
/// Observation is the right tool on this deployment target anyway.
@Observable
@MainActor
final class Store {
    private(set) var products: [Product] = []
    private(set) var entitlement: Entitlement = .empty
    private(set) var isWorking = false
    var lastError: String?

    static let subscriptionIDs = ["os.personal.sub.monthly", "os.personal.sub.yearly"]
    static let creditIDs = ["os.personal.credits.50", "os.personal.credits.200"]

    struct Entitlement: Decodable, Equatable {
        let subscription_status: String
        let product_id: String?
        let expires_at: Double?
        let credits: Int

        static let empty = Entitlement(
            subscription_status: "none", product_id: nil, expires_at: nil, credits: 0
        )

        var isSubscribed: Bool { subscription_status == "active" }
        /// Anything the hosted engines cost money for is available if either
        /// holds — a subscriber never spends credits.
        var canUseHostedAI: Bool { isSubscribed || credits > 0 }
    }

    /// `deinit` is nonisolated, so the handle it cancels has to be reachable
    /// from outside the actor. Only ever assigned once, in init.
    private nonisolated(unsafe) var listener: Task<Void, Never>?

    init() {
        listener = Task.detached { [weak self] in
            // Unfinished transactions land here, including ones that completed
            // while the app was closed.
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await self.submit(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    deinit { listener?.cancel() }

    // MARK: Catalogue

    func loadProducts() async {
        do {
            let all = try await Product.products(for: Store.subscriptionIDs + Store.creditIDs)
            // Cheapest first within each group reads as a ladder rather than
            // an arbitrary order.
            products = all.sorted { $0.price < $1.price }
        } catch {
            lastError = "Couldn't load the store: \(error.localizedDescription)"
        }
    }

    func subscriptions() -> [Product] {
        products.filter { Store.subscriptionIDs.contains($0.id) }
    }

    func creditPacks() -> [Product] {
        products.filter { Store.creditIDs.contains($0.id) }
    }

    // MARK: Buying

    func purchase(_ product: Product) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    // StoreKit itself couldn't verify the signature. Nothing
                    // to do but refuse; sending it on would only fail again
                    // server-side, more slowly.
                    lastError = "That purchase couldn't be verified."
                    return
                }
                await submit(transaction)
                await transaction.finish()

            case .userCancelled:
                break

            case .pending:
                // Ask-to-Buy and similar: approval may come days later, and
                // the listener will catch it.
                lastError = "Waiting for approval. It'll unlock once that's done."

            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Re-sends everything currently owned, for a reinstall or a new device.
    func restore() async {
        isWorking = true
        defer { isWorking = false }
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await submit(transaction)
            }
        }
        await refresh()
    }

    // MARK: Server

    /// Hands a transaction to the server, which verifies Apple's signature on
    /// it and returns the entitlement that follows.
    private func submit(_ transaction: Transaction) async {
        do {
            _ = try await BillingClient().verify(signedTransaction: transaction.jsonRepresentation)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The entitlement shown anywhere in the app comes from here, never from
    /// StoreKit directly.
    func refresh() async {
        do {
            entitlement = try await BillingClient().entitlement()
        } catch {
            // Leave the last known state rather than silently revoking access
            // because the network dropped.
            lastError = error.localizedDescription
        }
    }
}

/// Talks to the billing routes.
struct BillingClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) { self.auth = auth }

    private struct ErrorBody: Decodable { let error: String? }

    func verify(signedTransaction: Data) async throws -> Bool {
        // jsonRepresentation is UTF-8 JSON; the server wants the JWS string
        // that sits inside it under "signedTransaction" when present, and the
        // raw representation otherwise.
        let jws = String(data: signedTransaction, encoding: .utf8) ?? ""
        var r = try await request("/api/billing/verify", method: "POST")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["signedTransaction": jws])
        _ = try await send(r)
        return true
    }

    func entitlement() async throws -> Store.Entitlement {
        let data = try await send(try await request("/api/billing/entitlement", method: "GET"))
        return try JSONDecoder().decode(Store.Entitlement.self, from: data)
    }

    private func request(_ path: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw BillingError.badURL }
        guard let token = await auth.currentToken() else { throw BillingError.notSignedIn }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 30
        return r
    }

    private func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw BillingError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw BillingError.server(detail ?? "Request failed (\(http.statusCode))")
        }
        return data
    }
}

enum BillingError: LocalizedError {
    case badURL, badResponse, notSignedIn
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .badResponse: return "Unexpected server response"
        case .notSignedIn: return "Sign in to purchase"
        case .server(let m): return m
        }
    }
}
