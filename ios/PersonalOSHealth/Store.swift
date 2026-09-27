import Foundation
import StoreKit

/// Purchases, and what they entitle you to.
@Observable
@MainActor
final class Store {
    private(set) var products: [Product] = []
    private(set) var entitlement: Entitlement = .empty
    private(set) var isWorking = false
    var lastError: String?

    static let subscriptionIDs = ["os.personal.sub.monthly", "os.personal.sub.yearly"]
    /// Credit packs are gone.

    struct Entitlement: Decodable, Equatable {
        let subscription_status: String
        let product_id: String?
        let expires_at: Double?

        static let empty = Entitlement(
            subscription_status: "none", product_id: nil, expires_at: nil
        )

        /// What a subscription buys: the article archive.
        var isSubscribed: Bool { subscription_status == "active" }
    }

    /// `deinit` is nonisolated, so the handle it cancels has to be reachable from outside the
    /// actor.
    private nonisolated(unsafe) var listener: Task<Void, Never>?

    init() {
        listener = Task.detached { [weak self] in
            // Unfinished transactions land here, including ones that completed while the app was
            // closed.
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    // Article placement is paid per article and applied by the article server.
                    if transaction.productID == ArticlePlacement.productID {
                        if await ArticlePlacement.confirm(update) { await transaction.finish() }
                        continue
                    }
                    await self.submit(update)
                    await transaction.finish()
                }
            }
        }
    }

    deinit { listener?.cancel() }

    // MARK: Catalogue

    func loadProducts() async {
        do {
            // Cheapest first reads as a ladder rather than an arbitrary order.
            products = try await Product.products(for: Store.subscriptionIDs)
                .sorted { $0.price < $1.price }
        } catch {
            lastError = "Couldn't load the store: \(error.localizedDescription)"
        }
    }

    func subscriptions() -> [Product] {
        products.filter { Store.subscriptionIDs.contains($0.id) }
    }

    // MARK: Buying

    func purchase(_ product: Product) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified = verification else {
                    // StoreKit itself couldn't verify the signature.
                    lastError = "That purchase couldn't be verified."
                    return
                }
                await submit(verification)
                if case .verified(let transaction) = verification { await transaction.finish() }

            case .userCancelled:
                break

            case .pending:
                // Ask-to-Buy and similar: approval may come days later, and the listener will catch
                // it.
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
            if case .verified = result { await submit(result) }
        }
        await refresh()
    }

    // MARK: Server

    /// Hands a transaction to the server, which verifies Apple's signature on it and returns the
    /// entitlement that follows.
    private func submit(_ verification: VerificationResult<Transaction>) async {
        do {
            _ = try await BillingClient().verify(signedJWS: verification.jwsRepresentation)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The entitlement shown anywhere in the app comes from here, never from StoreKit directly.
    func refresh() async {
        do {
            entitlement = try await BillingClient().entitlement()
        } catch {
            // Leave the last known state rather than silently revoking access because the network
            // dropped.
            lastError = error.localizedDescription
        }
    }
}

/// Talks to the billing routes.
struct BillingClient {
    private let auth: AuthProvider

    init(auth: AuthProvider = Auth.provider) { self.auth = auth }

    /// Hands Apple's signed transaction to Convex, which checks the signature against Apple's roots
    /// and grants what the product is worth.
    func verify(signedJWS: String) async throws -> Bool {
        _ = try await Transport(auth: auth).action(
            "billing/receipts:verify", ["signedTransaction": signedJWS]
        )
        return true
    }

    func entitlement() async throws -> Store.Entitlement {
        let data = try await Transport(auth: auth).query("billing/entitlements:mine")
        return try JSONDecoder().decode(Store.Entitlement.self, from: data)
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
