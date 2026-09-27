import SwiftUI

/// The flash of brand between tapping the icon and the app appearing.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                GlyphRow()
                    .padding(.bottom, 26)

                Text("Personal OS")
                    .font(Theme.serif(40))
                    .foregroundStyle(Theme.text)

                Kicker(text: "Time well spent")
                    .tracking(3)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Kicker(text: "By ADEVSTUDIO", color: Theme.tertiaryText, size: 9)
                    .tracking(3.5)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 44)
            }
            // The wordmark is drawn at full strength on the first frame.
            .scaleEffect(appeared ? 1 : 0.97)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

/// The four faces of the ledger, one per metric group in `MetricCatalog`.
private struct GlyphRow: View {
    private let glyphs = [
        "figure.walk",      // Physical activity
        "shoeprints.fill",  // Mobility & gait
        "moon.stars",       // Recovery & environment
        "drop",             // Metabolic
    ]

    @State private var settled = false
    @State private var lit = -1

    var body: some View {
        HStack(spacing: 26) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { i, name in
                Image(systemName: name)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(lit == i ? Theme.accent : Theme.tertiaryText)
                    .opacity(settled ? 1 : 0)
                    .offset(y: settled ? 0 : 9)
                    .scaleEffect(lit == i ? 1.18 : (settled ? 1 : 0.8))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.72)
                            .delay(Double(i) * 0.07),
                        value: settled
                    )
                    .animation(.easeInOut(duration: 0.28), value: lit)
            }
        }
        .task {
            settled = true
            // Starts after the last glyph has landed, so the highlight reads as a second beat
            // rather than a collision.
            try? await Task.sleep(for: .milliseconds(380))
            for i in glyphs.indices {
                lit = i
                try? await Task.sleep(for: .milliseconds(150))
            }
            lit = -1
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
            // Long enough for the glyph row to play through, short enough not to be a wait.
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 0.45)) { showing = false }
        }
    }
}
