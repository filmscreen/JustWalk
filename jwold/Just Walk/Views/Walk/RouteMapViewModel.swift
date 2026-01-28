//
//  RouteMapViewModel.swift
//  Just Walk
//
//  ViewModel for fetching and managing workout route data.
//  Uses HKWorkoutRouteQuery to pull GPS points from HealthKit.
//

import Foundation
import HealthKit
import MapKit
import CoreLocation
import SwiftUI
import Combine

@MainActor
final class RouteMapViewModel: ObservableObject {

    // MARK: - Published State

    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var cameraPosition: MapCameraPosition = .automatic

    // Workout metadata
    @Published private(set) var totalDistance: Double = 0 // meters
    @Published private(set) var totalDuration: TimeInterval = 0

    // MARK: - Private

    private let healthStore = HKHealthStore()

    // MARK: - Computed Properties

    var formattedDistance: String {
        let miles = totalDistance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    var formattedDuration: String {
        let totalMinutes = Int(totalDuration) / 60
        let hours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(totalMinutes)m"
        }
    }

    var formattedPace: String? {
        guard totalDistance > 0, totalDuration > 0 else { return nil }

        // Calculate pace in minutes per mile
        let miles = totalDistance * 0.000621371
        let minutes = totalDuration / 60
        let pacePerMile = minutes / miles

        let paceMinutes = Int(pacePerMile)
        let paceSeconds = Int((pacePerMile - Double(paceMinutes)) * 60)

        return String(format: "%d:%02d /mi", paceMinutes, paceSeconds)
    }

    // MARK: - Route Loading

    func loadRoute(for workout: HKWorkout) async {
        isLoading = true
        error = nil

        // Extract workout metadata
        totalDuration = workout.duration

        if let distanceQuantity = workout.totalDistance {
            totalDistance = distanceQuantity.doubleValue(for: .meter())
        }

        do {
            // Step 1: Fetch workout routes associated with this workout
            let routes = try await fetchWorkoutRoutes(for: workout)

            guard let route = routes.first else {
                // No route data available
                isLoading = false
                return
            }

            // Step 2: Fetch location data from the route
            let locations = try await fetchRouteLocations(for: route)

            // Step 3: Extract coordinates
            routeCoordinates = locations.map { $0.coordinate }

            // Step 4: Calculate camera position to fit route
            updateCameraPosition()

        } catch {
            self.error = error
            print("Error loading route: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - HealthKit Queries

    /// Fetch HKWorkoutRoute objects associated with the workout
    private func fetchWorkoutRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: routeType,
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let routes = samples?.compactMap { $0 as? HKWorkoutRoute } ?? []
                continuation.resume(returning: routes)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch CLLocation data from an HKWorkoutRoute using HKWorkoutRouteQuery
    private func fetchRouteLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        return try await withCheckedThrowingContinuation { continuation in
            var allLocations: [CLLocation] = []
            var hasResumed = false

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error = error {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: error)
                    }
                    return
                }

                if let locations = locations {
                    allLocations.append(contentsOf: locations)
                }

                if done && !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: allLocations)
                }
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Camera Positioning

    /// Calculate map region to fit all route coordinates with padding
    private func updateCameraPosition() {
        guard !routeCoordinates.isEmpty else { return }

        // Calculate bounding box
        var minLat = routeCoordinates[0].latitude
        var maxLat = routeCoordinates[0].latitude
        var minLon = routeCoordinates[0].longitude
        var maxLon = routeCoordinates[0].longitude

        for coordinate in routeCoordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Calculate span with padding (20% extra)
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2

        // Ensure minimum span for very short routes
        let minDelta = 0.005 // Roughly 500 meters
        let adjustedLatDelta = max(latDelta, minDelta)
        let adjustedLonDelta = max(lonDelta, minDelta)

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: adjustedLatDelta,
                longitudeDelta: adjustedLonDelta
            )
        )

        cameraPosition = .region(region)
    }
}
