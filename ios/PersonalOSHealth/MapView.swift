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
                    // Two strokes: a wide soft one that reads as paint, and a
                    // narrow bright one so the route itself stays legible
                    // where it doubles back on a street already walked.
                    MapPolyline(coordinates: path)
                        .stroke(Theme.amber.opacity(0.22), style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: path)
                        .stroke(Theme.amber.opacity(0.85), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .top)

            panel
        }
        .background(Theme.linen)
        .onAppear {
            if !trail.points.isEmpty { camera = .automatic }
        }
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

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(text: trail.recording ? "Recording" : "Not recording",
                           color: trail.recording ? Theme.sage : Theme.dust)
                    Text(summary)
                        .font(Theme.serif(24))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                if !trail.points.isEmpty {
                    Button {
                        confirmingForget = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Theme.dust)
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
                    .foregroundStyle(Theme.dust)
                    .padding(.top, 8)
            }

            Button {
                Haptics.tap()
                trail.recording ? trail.stop() : trail.start()
            } label: {
                Text(trail.recording ? "Stop recording" : "Start recording")
                    .font(Theme.sans(14, medium: true))
                    .foregroundStyle(trail.recording ? Theme.ink : Theme.warm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(trail.recording ? Theme.warm : Theme.ink, in: Capsule())
            }
            .buttonStyle(.press)
            .disabled(trail.denied)
            .padding(.top, 16)
        }
        .padding(20)
        .background(Theme.linen, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var summary: String {
        guard !trail.points.isEmpty else { return "Nothing walked yet" }
        let count = outings.count
        return "\(count) \(count == 1 ? "outing" : "outings") painted"
    }
}
