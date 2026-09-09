import Foundation
import CoreLocation
import Combine

/// Where you have walked, kept on this phone.
///
/// This is the most sensitive thing the app holds. A day-by-day record of
/// somebody's movements says where they live, where they work, who they visit
/// and when they are out — more than any single health figure does. So it is
/// written to this device and nowhere else: there is no upload, no sync and no
/// server copy, and switching the recording off stops it at the source rather
/// than merely hiding the map.
@MainActor
final class Trail: NSObject, ObservableObject {
    static let shared = Trail()

    /// Whether the phone is currently recording. Off until asked for.
    @Published private(set) var recording = false
    /// Everything walked so far, oldest first.
    @Published private(set) var points: [Point] = []
    @Published private(set) var denied = false

    struct Point: Codable, Hashable {
        let lat: Double
        let lon: Double
        let at: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        var when: Date { Date(timeIntervalSince1970: at) }
    }

    private let manager = CLLocationManager()
    private var unsaved = 0

    /// Points closer together than this add nothing to a painted trail and
    /// would turn a day's walking into tens of thousands of rows.
    private static let metres: CLLocationDistance = 20

    /// The file. Application Support rather than Documents, because this is
    /// the app's own record and not a document anyone should be handed in
    /// Files.
    private static var store: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("trail.json")
    }

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = Self.metres
        // Tells iOS this is somebody moving under their own power, which is
        // what lets it pause updates when they have plainly stopped.
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
        load()
    }

    // MARK: Recording

    /// Asks for permission and starts. Safe to call when already running.
    func start() {
        guard !recording else { return }

        switch manager.authorizationStatus {
        case .notDetermined:
            // When-in-use first. Asking for Always outright is the prompt
            // people refuse, and iOS will offer the upgrade itself once it has
            // seen the app use location properly.
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            denied = true
            return
        default:
            break
        }

        manager.allowsBackgroundLocationUpdates =
            manager.authorizationStatus == .authorizedAlways
        manager.startUpdatingLocation()
        recording = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        recording = false
        save()
    }

    /// Removes the record entirely, from memory and from disk.
    ///
    /// Not a flag marking it hidden: somebody deleting where they have been
    /// means it should be gone.
    func forget() {
        points = []
        unsaved = 0
        try? FileManager.default.removeItem(at: Self.store)
    }

    // MARK: Disk

    private func load() {
        guard let data = try? Data(contentsOf: Self.store),
              let saved = try? JSONDecoder().decode([Point].self, from: data)
        else { return }
        points = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(points) else { return }
        // Written where the file system will not hand it to iCloud or a
        // backup that leaves the device.
        try? data.write(to: Self.store, options: .atomic)
        var url = Self.store
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        unsaved = 0
    }
}

extension Trail: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            for location in locations {
                // A fix the phone is unsure of will scatter the trail across
                // streets nobody walked down.
                guard location.horizontalAccuracy > 0,
                      location.horizontalAccuracy < 50 else { continue }

                if let last = points.last {
                    let previous = CLLocation(latitude: last.lat, longitude: last.lon)
                    guard location.distance(from: previous) >= Self.metres else { continue }
                }

                points.append(
                    Point(
                        lat: location.coordinate.latitude,
                        lon: location.coordinate.longitude,
                        at: location.timestamp.timeIntervalSince1970
                    )
                )
                unsaved += 1
            }

            // Batched. Writing the whole file on every fix would spend more
            // battery on the disk than on the radio.
            if unsaved >= 10 { save() }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways:
                self.manager.allowsBackgroundLocationUpdates = true
                denied = false
                if recording { self.manager.startUpdatingLocation() }
            case .authorizedWhenInUse:
                self.manager.allowsBackgroundLocationUpdates = false
                denied = false
            case .denied, .restricted:
                denied = true
                recording = false
            default:
                break
            }
        }
    }
}
