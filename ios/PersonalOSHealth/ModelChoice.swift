import Foundation
import SwiftUI

/// Which engine this phone should use, known without asking the server.
///
/// The authoritative choice lives in Convex so it follows a person between
/// devices, but the app cannot wait on a network round trip to answer "can I
/// write a report right now". A fresh install on a plane should still produce
/// one. So the choice is mirrored into local storage, and the server's copy is
/// treated as an update to that mirror rather than the only source.
///
/// The default is the on-device model whenever the hardware allows it. That is
/// the whole point: someone who has never heard of an API key gets a working
/// app, and only goes looking for a hosted model if they want a deeper read.
enum ModelChoice {
    static let deviceProvider = "apple"

    private static let providerKey = "personal_os_ai_provider"
    private static let modelKey = "personal_os_ai_model"

    /// True when this phone can generate without a network or a credential.
    static var deviceEngineReady: Bool {
        if #available(iOS 26.0, *) { return OnDeviceInsights.availability.isReady }
        return false
    }

    static var provider: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: providerKey), !stored.isEmpty {
                return stored
            }
            return deviceEngineReady ? deviceProvider : "ollama"
        }
        set { UserDefaults.standard.set(newValue, forKey: providerKey) }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }

    /// Generation happens here, not over the wire.
    static var isOnDevice: Bool { provider == deviceProvider }

    /// Accepts the server's copy of the selection.
    static func adopt(provider p: String, model m: String) {
        provider = p
        model = m
    }
}
