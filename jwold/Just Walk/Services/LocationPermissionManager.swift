//
//  LocationPermissionManager.swift
//  Just Walk
//
//  Manages location permission requests and authorization state.
//  Used by WalkTab to show map or permission placeholder.
//

import Foundation
import CoreLocation
import Combine
#if os(iOS)
import UIKit
#endif

@MainActor
final class LocationPermissionManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = LocationPermissionManager()

    // MARK: - Published State

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy

    // MARK: - Computed Properties

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasReducedAccuracy: Bool {
        accuracyAuthorization == .reducedAccuracy
    }

    var needsPermission: Bool {
        authorizationStatus == .notDetermined
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
        accuracyAuthorization = locationManager.accuracyAuthorization
    }

    // MARK: - Public Methods

    func requestWhenInUseAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func openSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationPermissionManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            accuracyAuthorization = manager.accuracyAuthorization
        }
    }
}
