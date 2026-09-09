import SwiftUI
import MapKit

/// Everywhere you have walked, painted onto the map.
///
/// The trail is drawn as one continuous stroke per outing rather than as a
/// line through every point ever recorded. Joining the end of Tuesday to the
/// start of Wednesday would draw a road across the city that nobody walked,
/// which is the one thing a map like this must not do.
struct MapView: View {
    @StateObject private var trail = Trail.shared

    @State private var camera: MapCameraPosition = .automatic
    @State private var confirmingForget = false

    /// A gap this long means the walking stopped and something else began.
    private static let gap: TimeInterval = 10 * 60

    /// The trail cut into separate outings.
    private var outings: [[CLLocationCoordinate2D]] {
        var out: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        var last: Date?

        for point in trail.points {
            if let last, point.when.timeIntervalSince(last) > Self.gap {
                if current.count > 1 { out.append(current) }
                current = []
            }
            current.append(point.coordinate)
            last = point.when
        }
        if current.count > 1 { out.append(current) }
        return out
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                ForEach(Array(outings.enumerated()), id: \.offset) { _, path in
                    // Three passes, which is what gives a stroke the glow
                    // rather than the flatness of a drawn line: a wide dim
                    // halo, a mid band, then a bright core on top.
                    MapPolyline(coordinates: path)
                        .stroke(Self.glow.opacity(0.16), style: Self.stroke(26))
                    MapPolyline(coordinates: path)
                        .stroke(Self.glow.opacity(0.38), style: Self.stroke(12))
                    MapPolyline(coordinates: path)
                        .stroke(Self.core, style: Self.stroke(3))
                }
                UserAnnotation()
            }
            // Flat and stripped: no points of interest, no terrain relief, no
            // colour competing with the trail. Tesla's screen is not a map of
            // a place, it is a diagram of where you are, and the difference is
            // almost entirely what has been left out.
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControlVisibility(.hidden)
            // Dark regardless of the phone's own setting. The ground has to be
            // darker than the trail or nothing glows.
            .preferredColorScheme(.dark)
            .ignoresSafeArea()

            panel
        }
        .background(Self.ground)
        .onAppear(perform: frame)
        .onChange(of: trail.recording) { _, _ in frame() }
        .confirmationDialog(
            "Forget everywhere you have walked?",
            isPresented: $confirmingForget,
            titleVisibility: .visible
        ) {
            Button("Forget it all", role: .destructive) {
                Haptics.tap()
                trail.forget()
                frame()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The trail is deleted from this phone. There is no copy anywhere else, so this cannot be undone.")
        }
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

    /// Looking along the ground rather than straight down at it.
    ///
    /// The tilt is what makes this read as a world rather than a chart, and it
    /// is most of why Tesla's screen looks the way it does. Following while
    /// recording, and pulled back to hold the whole trail when not.
    private func frame() {
        withAnimation(.easeInOut(duration: 0.8)) {
            if trail.recording {
                camera = .userLocation(
                    followsHeading: true,
                    fallback: .camera(MapCamera(
                        centerCoordinate: trail.points.last?.coordinate
                            ?? CLLocationCoordinate2D(latitude: 10.65, longitude: -61.51),
                        distance: 900,
                        heading: 0,
                        pitch: 60
                    ))
                )
            } else if let last = trail.points.last {
                camera = .camera(MapCamera(
                    centerCoordinate: last.coordinate,
                    distance: 2600,
                    heading: 0,
                    pitch: 45
                ))
            } else {
                camera = .userLocation(followsHeading: false, fallback: .automatic)
            }
        }
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
