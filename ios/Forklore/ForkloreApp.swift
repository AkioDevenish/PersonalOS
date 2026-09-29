import SwiftUI

@main
struct ForkloreApp: App {
    @StateObject private var health = HealthKitManager()
    /// Who is signed in.
    @StateObject private var session = Session.shared
    /// Nothing in this app works without a connection, so it is asked first.
    @StateObject private var network = Network.shared
    /// Only for the device token Apple hands back; nothing else uses it.
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate
    /// Owned at app level, not by the paywall: transactions arrive whenever Apple feels like it — a
    /// renewal, an Ask-to-Buy approval days later, a purchase made on another device — and the
    /// listener has to be running to catch them.
    @State private var store = Store()
    /// Owned at app level so the notification delegate is set before any notification can arrive,
    /// and so a tap can route the app from anywhere.
    @StateObject private var notifier = Notifier.shared
    @Environment(\.scenePhase) private var scene

    var body: some Scene {
        WindowGroup {
            SplashGate {
                if !network.online {
                    // In front of everything, including the welcome page: an account cannot be made
                    // offline either.
                    OfflineView()
                        .transition(.opacity)
                } else {
                    // The session is restored on launch; until it has, showing the welcome page
                    // would flash at somebody already signed in.
                    switch session.state {
                    case .restoring: LoadingView()
                    case .signedIn: OnboardingGate { RootView() }
                    case .signedOut: WelcomeView()
                    }
                }
            }
            .animation(Theme.Motion.flow, value: network.online)
            .environmentObject(health)
            .environmentObject(notifier)
            .environment(store)
            .environmentObject(session)
            .environmentObject(network)
            .onAppear { notifier.start() }
            .task { await session.restore() }
            .task { await Push.registerIfAllowed() }
            // A listed practitioner is present whenever their app is.
            .onChange(of: scene) { _, phase in
                guard phase == .active else { return }
                Task { await SpecialistsClient().heartbeat() }
                // Today's readings go up on their own, at most every half hour, rather than waiting
                // for somebody to press a button they should never have had to know about.
                Task { await AutoSync.shared.runIfDue(health) }
            }
        }
    }
}

/// Held while the session is restored.
struct LoadingView: View {
    var body: some View {
        VStack {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}
