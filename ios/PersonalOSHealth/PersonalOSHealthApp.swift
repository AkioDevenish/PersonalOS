import SwiftUI
import ClerkKit

@main
struct PersonalOSHealthApp: App {
    @StateObject private var health = HealthKitManager()
    @State private var clerk = Clerk.configure(publishableKey: Auth.publishableKey)
    /// Owned at app level, not by the paywall: transactions arrive whenever
    /// Apple feels like it — a renewal, an Ask-to-Buy approval days later, a
    /// purchase made on another device — and the listener has to be running to
    /// catch them.
    @State private var store = Store()
    /// Owned at app level so the notification delegate is set before any
    /// notification can arrive, and so a tap can route the app from anywhere.
    @StateObject private var notifier = Notifier.shared

    var body: some Scene {
        WindowGroup {
            SplashGate {
                // Clerk restores any existing session on launch; until it has,
                // showing sign-in would flash at an already-signed-in user.
                // The splash covers that moment, so it costs nothing visible.
                if !clerk.isLoaded {
                    LoadingView()
                } else if clerk.user != nil {
                    RootView()
                } else {
                    SignInView()
                }
            }
            .environmentObject(health)
            .environmentObject(notifier)
            .environment(store)
            .environment(clerk)
            .onAppear { notifier.start() }
        }
    }
}

/// Held while Clerk restores the session — the brand mark, not a spinner.
struct LoadingView: View {
    var body: some View {
        VStack {
            Text("❧")
                .font(Theme.serif(28))
                .foregroundStyle(Theme.amber)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.linen)
    }
}
