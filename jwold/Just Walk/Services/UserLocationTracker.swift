//
//  UserLocationTracker.swift
//  Just Walk
//
//  Simple location observer that publishes current user coordinates
//  for map camera positioning with offset.
//

import Foundation
import CoreLocation
import Combine

/// Equatable wrapper for CLLocationCoordinate2D
struct EquatableCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
final class UserLocationTracker: NSObject, ObservableObject {
    @Published var currentLocation: EquatableCoordinate?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    func startTracking() {
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    deinit {
        locationManager.stopUpdatingLocation()
    }
}

extension UserLocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = EquatableCoordinate(location.coordinate)
        }
    }
}
