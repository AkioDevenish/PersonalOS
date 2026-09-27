import Foundation
import SwiftUI

/// Which engine this phone should use, known without asking the server.
enum ModelChoice {
    static let deviceProvider = "apple"

    private static let providerKey = "personal_os_ai_provider"
    private static let modelKey = "personal_os_ai_model"

    /// True when this phone can generate without a network or a credential.
    static var deviceEngineReady: Bool { OnDeviceInsights.availability.isReady }

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
