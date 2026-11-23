import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var routePoints: [CoordinatePoint] = []
    @Published private(set) var totalDistanceMeters: Double = 0
    @Published private(set) var currentPaceSecondsPerKm: TimeInterval?

    private let manager = CLLocationManager()
    private var isTracking = false
    private var isPaused = false
    private var lastValidLocation: CLLocation?
    private var recentLocations: [CLLocation] = []

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 4
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermissions() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func startPreviewLocation() {
        requestPermissions()
        manager.startUpdatingLocation()
    }

    func startTracking() {
        requestPermissions()
        routePoints.removeAll()
        recentLocations.removeAll()
        totalDistanceMeters = 0
        currentPaceSecondsPerKm = nil
        lastValidLocation = nil
        isTracking = true
        isPaused = false

        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func pauseTracking() {
        isPaused = true
        lastValidLocation = nil
        recentLocations.removeAll()
        currentPaceSecondsPerKm = nil
    }

    func resumeTracking() {
        isPaused = false
        lastValidLocation = nil
        recentLocations.removeAll()
    }

    func stopTracking() {
        isTracking = false
        isPaused = false
        lastValidLocation = nil
        recentLocations.removeAll()
        currentPaceSecondsPerKm = nil
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.stopUpdatingLocation()
    }

    private func handleLocations(_ locations: [CLLocation]) {
        for location in locations {
            // Filtra punti GPS troppo imprecisi o obsoleti
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= 25,
                  abs(location.timestamp.timeIntervalSinceNow) < 15 else {
                continue
            }

            currentLocation = location

            guard isTracking, !isPaused else { continue }

            if let previous = lastValidLocation {
                let delta = location.distance(from: previous)
                let dt = location.timestamp.timeIntervalSince(previous.timestamp)
                // Ignora piccoli jitter da fermo e salti GPS irrealistici (> 12 m/s)
                if delta >= 2.0, dt > 0, (delta / dt) < 12.0 {
                    totalDistanceMeters += delta
                    routePoints.append(
                        CoordinatePoint(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            timestamp: location.timestamp
                        )
                    )
                    lastValidLocation = location
                    updateRollingPace(with: location)
                }
            } else {
                lastValidLocation = location
                routePoints.append(
                    CoordinatePoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        timestamp: location.timestamp
                    )
                )
                recentLocations = [location]
            }
        }
    }

    private func updateRollingPace(with location: CLLocation) {
        recentLocations.append(location)
        let cutoff = location.timestamp.addingTimeInterval(-15)
        recentLocations.removeAll { $0.timestamp < cutoff }

        guard recentLocations.count >= 2,
              let first = recentLocations.first,
              let last = recentLocations.last else {
            return
        }

        var dist: Double = 0
        for idx in 1..<recentLocations.count {
            dist += recentLocations[idx].distance(from: recentLocations[idx - 1])
        }
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)

        if dist >= 10, elapsed >= 3 {
            let speedMetersPerSec = dist / elapsed
            if speedMetersPerSec > 0.5 {
                currentPaceSecondsPerKm = 1000.0 / speedMetersPerSec
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.handleLocations(locations)
        }
    }
}
