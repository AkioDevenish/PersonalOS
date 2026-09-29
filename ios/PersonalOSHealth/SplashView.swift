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

    var body: some View {
        ZStack {
            content
            if showing {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Long enough for the spoon and the writing to finish.
            try? await Task.sleep(for: .milliseconds(2600))
            withAnimation(.easeInOut(duration: 0.45)) { showing = false }
        }
    }
}
