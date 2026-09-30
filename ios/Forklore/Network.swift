import Foundation
import Combine
import Network

/// Whether there is a connection, watched rather than discovered by failing.
@MainActor
final class Network: ObservableObject {
    static let shared = Network()

    /// Starts true so a launch on a good connection never flashes the offline page while the first
    /// path update arrives.
    @Published private(set) var online = true
    @Published private(set) var checking = false

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.online = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "network.path"))
    }

    /// Asks the database whether it is reachable, for the retry button.
    func recheck() async {
        checking = true
        defer { checking = false }
        guard let url = URL(string: AppConfig.convexURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if (try? await URLSession.shared.data(for: request)) != nil {
            online = true
        }
    }
}
