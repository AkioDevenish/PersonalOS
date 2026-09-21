import Foundation
import Combine
import Network

/// Whether there is a connection, watched rather than discovered by failing.
///
/// Everything this app shows comes from the database: the ledger, the
/// articles, the directory, even signing in. Offline, each of those screens
/// would fail on its own, in its own words, at its own moment. One honest
/// answer at the front is better than a dozen quiet ones behind it.
///
/// Two questions, and both matter. `NWPathMonitor` says whether there is a
/// route to the network at all, which is instant and free. Whether anything
/// answers at the other end is a different question — a café's sign-in page
/// satisfies the first and not the second — so the retry button asks the
/// database itself.
@MainActor
final class Network: ObservableObject {
    static let shared = Network()

    /// Starts true so a launch on a good connection never flashes the offline
    /// page while the first path update arrives.
    @Published private(set) var online = true
    @Published private(set) var checking = false

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.online = path.status == .satisfied
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
