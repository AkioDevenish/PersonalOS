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
        ZStack {
            Theme.linen.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                GlyphRow()
                    .padding(.bottom, 26)

                Text("Personal OS")
                    .font(Theme.serif(40))
                    .foregroundStyle(Theme.ink)

                Kicker(text: "Time well spent")
                    .tracking(3)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Kicker(text: "By ADEVSTUDIO", color: Theme.dust, size: 9)
                    .tracking(3.5)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 44)
            }
            // The wordmark is drawn at full strength on the first frame. The
            // whole splash only lives for about a second and a half, so a
            // fade-in would spend a chunk of that showing nothing.
            .scaleEffect(appeared ? 1 : 0.97)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

/// The four faces of the ledger, one per metric group in `MetricCatalog`.
///
/// They animate twice over: each glyph rises into place on a stagger, then a
/// single amber highlight walks along the row. Amber is the design's only
/// punctuation colour, so lighting one glyph at a time keeps the flash alive
/// without turning it into a light show.
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
                    .foregroundStyle(lit == i ? Theme.amber : Theme.dust)
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
            // Starts after the last glyph has landed, so the highlight reads
            // as a second beat rather than a collision.
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
            // Long enough for the glyph row to play through, short enough not
            // to be a wait.
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 0.45)) { showing = false }
        }
    }
}
