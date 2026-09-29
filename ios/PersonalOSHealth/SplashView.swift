import SwiftUI

/// The flash of brand between tapping the icon and the app appearing.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.gradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ForkloreWordmark(size: 64)

                Kicker(text: "Every dish has a story")
                    .tracking(3)
                    .padding(.top, 14)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Kicker(text: "By ADEVSTUDIO", color: Theme.tertiaryText, size: 9)
                    .tracking(3.5)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.9)) { appeared = true }
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
