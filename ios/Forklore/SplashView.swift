import SwiftUI

/// The flash of brand between tapping the icon and the app appearing.
struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.gradient.ignoresSafeArea()
            ForkloreWordmark(size: 64, showsFork: false)
        }
    }
}

/// Holds the splash briefly over whatever the app is showing, then dissolves.
struct SplashGate<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var showing = true
    /// The app stays hidden until the splash has gone, so the two wordmarks never overlap mid-fade.
    @State private var revealed = false

    var body: some View {
        ZStack {
            Theme.gradient.ignoresSafeArea()
            content.opacity(revealed ? 1 : 0)
            if showing {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Long enough for the writing to finish.
            try? await Task.sleep(for: .milliseconds(2600))
            withAnimation(.easeIn(duration: 0.3)) { showing = false }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.35)) { revealed = true }
        }
    }
}
