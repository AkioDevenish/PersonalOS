import SwiftUI
import ClerkKit

@main
struct PersonalOSHealthApp: App {
    @StateObject private var health = HealthKitManager()
    @State private var clerk = Clerk.configure(publishableKey: Auth.publishableKey)

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
            .environment(clerk)
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
