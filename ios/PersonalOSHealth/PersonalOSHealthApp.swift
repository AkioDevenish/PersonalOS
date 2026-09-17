import SwiftUI
import ClerkKit

@main
struct PersonalOSHealthApp: App {
    @StateObject private var health = HealthKitManager()
    @State private var clerk = Clerk.configure(publishableKey: Auth.publishableKey)
    /// Only for the device token Apple hands back; nothing else uses it.
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate
    /// Owned at app level, not by the paywall: transactions arrive whenever
    /// Apple feels like it — a renewal, an Ask-to-Buy approval days later, a
    /// purchase made on another device — and the listener has to be running to
    /// catch them.
    @State private var store = Store()
    /// Owned at app level so the notification delegate is set before any
    /// notification can arrive, and so a tap can route the app from anywhere.
    @StateObject private var notifier = Notifier.shared
    @Environment(\.scenePhase) private var scene

    var body: some Scene {
        WindowGroup {
            SplashGate {
                // Clerk restores any existing session on launch; until it has,
                // showing sign-in would flash at an already-signed-in user.
                // The splash covers that moment, so it costs nothing visible.
                if !clerk.isLoaded {
                    LoadingView()
                } else if clerk.user != nil {
                    OnboardingGate { RootView() }
                } else {
                    SignInView()
                }
            }
            .environmentObject(health)
            .environmentObject(notifier)
            .environment(store)
            .environment(clerk)
            .onAppear { notifier.start() }
            .task { await Push.registerIfAllowed() }
            // A listed practitioner is present whenever their app is. The
            // call is a no-op for everybody else, which is nearly everybody,
            // so it costs one request rather than a check to find out.
            .onChange(of: scene) { _, phase in
                guard phase == .active else { return }
                Task { await SpecialistsClient().heartbeat() }
                // Today's readings go up on their own, at most every half
                // hour, rather than waiting for somebody to press a button
                // they should never have had to know about.
                Task { await AutoSync.shared.runIfDue(health) }
            }
        }
    }
}

/// Held while Clerk restores the session.
///
/// Deliberately empty. It shows for a fraction of a second on a good
/// connection, and anything put here is a flash of something rather than a
/// thing anybody reads.
struct LoadingView: View {
    var body: some View {
        VStack {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
