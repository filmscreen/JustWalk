//
//  WalkMapViewModel.swift
//  Just Walk
//
//  View model for map background on Walk tab.
//  Manages camera position and recenter logic.
//

import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
final class WalkMapViewModel: ObservableObject {

    // MARK: - Published State

    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var userCoordinate: CLLocationCoordinate2D?

    // MARK: - Dependencies

    private let locationTracker = UserLocationTracker()
    private let locationManager = LocationPermissionManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isLocationAuthorized: Bool {
        locationManager.isAuthorized
    }

    // MARK: - Init

    init() {
        setupInitialRegion()
        observeLocationChanges()
    }

    // MARK: - Setup

    private func setupInitialRegion() {
        // Set initial region centered on user (~0.5 mile radius = ~800m)
        if let coord = locationTracker.currentLocation?.coordinate {
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )
            cameraPosition = .region(region)
        }
    }

    private func observeLocationChanges() {
        // Update camera when location first becomes available
        locationTracker.$currentLocation
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self else { return }
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 800,
                    longitudinalMeters: 800
                )
                self.cameraPosition = .region(region)
            }
            .store(in: &cancellables)

        // Continuously update user coordinate for custom annotation
        locationTracker.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.userCoordinate = location?.coordinate
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func recenterOnUser() {
        guard let coord = locationTracker.currentLocation?.coordinate else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            ))
        }
    }
}
