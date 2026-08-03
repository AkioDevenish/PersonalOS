import SwiftUI

/// The flash of brand between tapping the icon and the app appearing.
///
/// Two halves, deliberately. The system launch screen is a flat linen colour
/// (UILaunchScreen in Info.plist), so the very first frame is already the
/// right colour rather than a white flash. This view then draws the wordmark
/// on that same linen and fades out — so the transition reads as one continuous
/// surface rather than two screens swapping.
///
/// It is a flash, not a loading screen: nothing waits on it, and the app is
/// live underneath the whole time.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Personal OS")
                .font(Theme.serif(40))
                .foregroundStyle(Theme.ink)

            Kicker(text: "Time well spent")
                .tracking(3)
                .opacity(appeared ? 1 : 0)
        }
        // The wordmark is drawn at full strength on the first frame. The whole
        // splash only lives for about a second, so a fade-in would spend a
        // third of that window showing nothing.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.linen)
        // A small settle rather than a hard cut — the wordmark arrives, it
        // doesn't pop.
        .scaleEffect(appeared ? 1 : 0.97)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
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
            // Long enough to register, short enough not to be a wait.
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.45)) { showing = false }
        }
    }
}
