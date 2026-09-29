import Foundation
import Testing
@testable import PersonalOSHealth

/// A token fit for reading the expiry out of: header, payload and signature, base64url without
/// padding, as a JWT is sent.
private func jwt(_ payload: String) -> String {
    let body = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return "eyJhbGciOiJSUzI1NiJ9.\(body).c2lnbmF0dXJl"
}

/// Staying signed in: when a token runs out, and which failures end the session.
@MainActor
struct SignInTests {
    @Test func readsWhenATokenRunsOut() {
        let expiry = Session.expiry(of: jwt(#"{"sub":"user_1","exp":1700000000}"#))
        #expect(expiry == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func readsAPayloadThatNeedsPadding() {
        // Lengths that are not a multiple of three need one or two "=" put back before decoding.
        for sub in ["a", "ab", "abc"] {
            #expect(Session.expiry(of: jwt(#"{"sub":"\#(sub)","exp":42}"#)) == Date(timeIntervalSince1970: 42))
        }
    }

    @Test func aTokenItCannotReadHasNoExpiry() {
        #expect(Session.expiry(of: "not-a-jwt") == nil)
        #expect(Session.expiry(of: jwt(#"{"sub":"user_1"}"#)) == nil)
        #expect(Session.expiry(of: "a.%%%.c") == nil)
    }

    @Test func onlyTheServerSayingNoEndsTheSession() {
        #expect(Session.isRefusal(TransportError.server("Invalid refresh token")))
        #expect(Session.isRefusal(TransportError.http(401, "")))
        #expect(Session.isRefusal(TransportError.http(400, "")))
    }

    @Test func aNetworkThatDidNotAnswerKeepsTheSession() {
        #expect(!Session.isRefusal(URLError(.notConnectedToInternet)))
        #expect(!Session.isRefusal(URLError(.timedOut)))
        #expect(!Session.isRefusal(TransportError.http(408, "")))
        #expect(!Session.isRefusal(TransportError.http(429, "")))
        #expect(!Session.isRefusal(TransportError.http(503, "")))
    }

    @Test func namesTheAccountByWhatItHas() throws {
        let decode = { (json: String) in
            try JSONDecoder().decode(Session.Account.self, from: Data(json.utf8))
        }
        #expect(try decode(#"{"id":"u","name":"Ana","email":"a@b.co"}"#).displayName == "Ana")
        #expect(try decode(#"{"id":"u","name":"  ","email":"a@b.co"}"#).displayName == "a@b.co")
        #expect(try decode(#"{"id":"u"}"#).displayName == "Your account")
    }
}

/// What comes back from Convex, before any screen sees it.
@MainActor
struct TransportTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test func handsBackTheValueAlone() throws {
        let value = try Transport.unwrap(data(#"{"status":"success","value":{"n":3}}"#), status: 200)
        let object = try #require(try JSONSerialization.jsonObject(with: value) as? [String: Int])
        #expect(object == ["n": 3])
    }

    @Test func aMissingValueIsNull() throws {
        let value = try Transport.unwrap(data(#"{"status":"success"}"#), status: 200)
        #expect(String(decoding: value, as: UTF8.self) == "null")
    }

    @Test func aFunctionThatThrewIsAnError() {
        let error = #expect(throws: TransportError.self) {
            try Transport.unwrap(data(#"{"status":"error","errorMessage":"No such session"}"#), status: 200)
        }
        #expect(error?.errorDescription == "No such session")
    }

    @Test func aFailedRequestKeepsItsStatus() {
        let error = #expect(throws: TransportError.self) {
            try Transport.unwrap(data("Unauthorized"), status: 401)
        }
        guard case .http(401, "Unauthorized")? = error else {
            Issue.record("Expected a 401, got \(String(describing: error))")
            return
        }
        #expect(error?.errorDescription == "Your session expired. Sign in again")
    }

    @Test func somethingThatIsNotJSONIsABadResponse() {
        #expect(throws: (any Error).self) { try Transport.unwrap(data("<html>"), status: 200) }
    }

    @Test func tellsACancelledRequestApart() {
        #expect(CancellationError().isCancellation)
        #expect(URLError(.cancelled).isCancellation)
        #expect(!URLError(.timedOut).isCancellation)
    }
}

/// Paying for a session, as far as the phone decides anything about it.
@MainActor
struct CheckoutTests {
    private func page(_ json: String) throws -> URL {
        try SessionClient.checkoutPage(from: Data(json.utf8))
    }

    @Test func sendsThePayerToTheProcessorsPage() throws {
        #expect(try page(#"{"url":"https://wam.test/pay","paid":false}"#) == URL(string: "https://wam.test/pay"))
    }

    @Test func aSessionAlreadyPaidNeedsNoPage() {
        #expect(throws: PaymentUnavailable.alreadySettled) {
            try page(#"{"url":null,"paid":true}"#)
        }
    }

    @Test func noProcessorSaysSoPlainly() {
        #expect(throws: PaymentUnavailable.noProcessor) {
            try page(#"{"url":null,"paid":false,"error":"No payment processor is connected yet."}"#)
        }
    }

    @Test func noPageAndNoReasonIsABadResponse() {
        let error = #expect(throws: TransportError.self) {
            try page(#"{"paid":false}"#)
        }
        guard case .badResponse? = error else {
            Issue.record("Expected a bad response, got \(String(describing: error))")
            return
        }
    }

    @Test func readsWhatIsOwedWhenASessionOpens() throws {
        let opened = try JSONDecoder().decode(SessionClient.Opened.self, from: Data(
            #"{"id":"c1","kind":"text","price_minor":4000,"currency":"TTD","payment_status":"pending"}"#.utf8
        ))
        #expect(opened.owing)
        #expect(!opened.free)
        #expect(opened.price.contains("40.00"))
    }

    @Test func aSubscriptionCountsOnlyWhileActive() throws {
        let decode = { (status: String) in
            try JSONDecoder().decode(Store.Entitlement.self, from: Data(
                #"{"subscription_status":"\#(status)","product_id":"os.personal.sub.monthly","expires_at":1}"#.utf8
            ))
        }
        #expect(try decode("active").isSubscribed)
        #expect(try !decode("expired").isSubscribed)
        #expect(!Store.Entitlement.empty.isSubscribed)
    }
}
