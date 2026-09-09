import SwiftUI
import CoreLocation

/// Everywhere you have walked, painted onto the map.
///
/// The trail is drawn as one continuous stroke per outing rather than as a
/// line through every point ever recorded. Joining the end of Tuesday to the
/// start of Wednesday would draw a road across the city that nobody walked,
/// which is the one thing a map like this must not do.
struct MapView: View {
    @StateObject private var trail = Trail.shared

    @State private var confirmingForget = false

    /// A gap this long means the walking stopped and something else began.
    private static let gap: TimeInterval = 10 * 60

    /// The trail cut into separate outings.
    private var outings: [[Trail.Point]] {
        var out: [[Trail.Point]] = []
        var current: [Trail.Point] = []
        var last: Date?

        for point in trail.points {
            if let last, point.when.timeIntervalSince(last) > Self.gap {
                if current.count > 1 { out.append(current) }
                current = []
            }
            current.append(point)
            last = point.when
        }
        if current.count > 1 { out.append(current) }
        return out
    }

    /// Which way the last stretch of walking was going, so the world turns to
    /// face it. Averaged over the last few points, because one step's bearing
    /// swings wildly and the whole scene would swing with it.
    private var heading: Double {
        let tail = trail.points.suffix(6)
        guard tail.count >= 2, let first = tail.first, let last = tail.last else { return 0 }
        let latitude = last.lat * .pi / 180
        let east = (last.lon - first.lon) * cos(latitude)
        let north = last.lat - first.lat
        guard abs(east) > 1e-9 || abs(north) > 1e-9 else { return 0 }
        return atan2(east, north)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TrailCanvas(
                outings: outings,
                focus: trail.points.last,
                heading: heading
            )
            .ignoresSafeArea()

            if trail.points.isEmpty { nothingYet }

            panel
        }
        .background(Self.ground)
        .confirmationDialog(
            "Forget everywhere you have walked?",
            isPresented: $confirmingForget,
            titleVisibility: .visible
        ) {
            Button("Forget it all", role: .destructive) {
                Haptics.tap()
                trail.forget()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The trail is deleted from this phone. There is no copy anywhere else, so this cannot be undone.")
        }
    }

    /// An empty grid is not obviously a map waiting to be filled in.
    private var nothingYet: some View {
        VStack(spacing: 10) {
            Text("Nothing walked yet")
                .font(Theme.serif(28))
                .foregroundStyle(.white)
            Text("Start recording and the ground fills in behind you.")
                .font(Theme.sans(12.5))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 190)
    }

    // MARK: The look

    /// Near black, so the trail is the brightest thing on screen.
    private static let ground = Color(red: 0.07, green: 0.07, blue: 0.08)
    /// A cold white-blue. Warm amber belongs on linen; on a dark ground it
    /// muddies, and this is the one screen in the app that is not paper.
    private static let core = Color(red: 0.82, green: 0.90, blue: 1.0)
    private static let glow = Color(red: 0.44, green: 0.68, blue: 1.0)

    private static func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    /// The controls, floating over the map rather than beside it.
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(text: trail.recording ? "Recording" : "Not recording",
                           color: trail.recording ? Self.core : .white.opacity(0.45))
                    Text(summary)
                        .font(Theme.serif(24))
                        .foregroundStyle(.white)
                }
                Spacer()
                if !trail.points.isEmpty {
                    Button {
                        confirmingForget = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.5))
                            .environment(\.symbolVariants, .none)
                    }
                    .buttonStyle(.press)
                }
            }

            if trail.denied {
                Text("Location is turned off for Personal OS. Open Settings, then Privacy and Security, then Location Services, and allow it.")
                    .font(Theme.sans(11.5))
                    .foregroundStyle(Theme.amber)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            } else {
                Text(trail.recording
                     ? "Kept on this phone. Nothing is uploaded."
                     : "Nothing is being recorded. The map fills in as you walk.")
                    .font(Theme.sans(11.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 8)
            }

            Button {
                Haptics.tap()
                trail.recording ? trail.stop() : trail.start()
            } label: {
                Text(trail.recording ? "Stop recording" : "Start recording")
                    .font(Theme.sans(14, medium: true))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(trail.recording ? Color.white.opacity(0.85) : Self.core, in: Capsule())
            }
            .buttonStyle(.press)
            .disabled(trail.denied)
            .padding(.top, 16)
        }
        .padding(20)
        // Glass over the map rather than a solid slab, so the trail stays
        // visible underneath the controls that talk about it.
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var summary: String {
        guard !trail.points.isEmpty else { return "Nothing walked yet" }
        let count = outings.count
        return "\(count) \(count == 1 ? "outing" : "outings") painted"
    }
}
