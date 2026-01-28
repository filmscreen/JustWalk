//
//  SavedRouteManager.swift
//  Just Walk
//
//  Manages saved routes with Pro gating (free users: 3 routes, Pro: unlimited).
//  Persists routes to UserDefaults and handles coordinate conversion.
//

import Foundation
import MapKit
import CoreLocation
import Combine

/// Manages saved Magic Routes with Pro gating
@MainActor
final class SavedRouteManager: ObservableObject {
    static let shared = SavedRouteManager()

    private let defaults = UserDefaults.standard
    private let storageKey = "savedRoutes_v1"
    private let maxFreeRoutes = 3

    // MARK: - Published Properties

    @Published private(set) var savedRoutes: [SavedRoute] = []

    // MARK: - Initialization

    private init() {
        loadRoutes()
    }

    // MARK: - Pro Gating

    /// Check if user can save more routes
    func canSaveMore() -> Bool {
        if SubscriptionManager.shared.isPro {
            return true
        }
        return savedRoutes.count < maxFreeRoutes
    }

    /// Number of routes remaining for free users
    var routesRemaining: Int {
        if SubscriptionManager.shared.isPro {
            return Int.max
        }
        return max(0, maxFreeRoutes - savedRoutes.count)
    }

    /// Whether user is at the free limit
    var isAtFreeLimit: Bool {
        !SubscriptionManager.shared.isPro && savedRoutes.count >= maxFreeRoutes
    }

    // MARK: - Route Management

    /// Save a generated route
    @discardableResult
    func saveRoute(from route: RouteGenerator.GeneratedRoute, name: String) -> SavedRoute? {
        guard canSaveMore() else { return nil }

        let coordinates = extractCoordinates(from: route.polyline)
        let center = calculateCenter(of: coordinates)

        let savedRoute = SavedRoute(
            name: name,
            distance: route.totalDistance,
            estimatedTime: route.estimatedTime,
            polylineCoordinates: coordinates,
            centerLatitude: center.latitude,
            centerLongitude: center.longitude
        )

        savedRoutes.insert(savedRoute, at: 0)
        saveRoutes()

        return savedRoute
    }

    /// Delete a saved route
    func deleteRoute(_ route: SavedRoute) {
        savedRoutes.removeAll { $0.id == route.id }
        saveRoutes()
    }

    /// Delete route by ID
    func deleteRoute(id: UUID) {
        savedRoutes.removeAll { $0.id == id }
        saveRoutes()
    }

    /// Rename a saved route
    func renameRoute(_ route: SavedRoute, to newName: String) {
        guard let index = savedRoutes.firstIndex(where: { $0.id == route.id }) else { return }
        savedRoutes[index].name = newName
        saveRoutes()
    }

    /// Record that a route was walked
    func recordWalk(for route: SavedRoute) {
        guard let index = savedRoutes.firstIndex(where: { $0.id == route.id }) else { return }
        savedRoutes[index].timesWalked += 1
        savedRoutes[index].lastWalkedAt = Date()
        saveRoutes()
    }

    // MARK: - Coordinate Conversion

    /// Extract coordinates from MKPolyline for storage
    func extractCoordinates(from polyline: MKPolyline) -> [CoordinatePair] {
        var coords: [CoordinatePair] = []
        let points = polyline.points()
        for i in 0..<polyline.pointCount {
            let coord = points[i].coordinate
            coords.append(CoordinatePair(latitude: coord.latitude, longitude: coord.longitude))
        }
        return coords
    }

    /// Reconstruct MKPolyline from saved coordinates
    func polyline(for route: SavedRoute) -> MKPolyline {
        let coords = route.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        return MKPolyline(coordinates: coords, count: coords.count)
    }

    /// Convert SavedRoute to GeneratedRoute for walking
    func toGeneratedRoute(_ saved: SavedRoute) -> RouteGenerator.GeneratedRoute {
        let coords = saved.polylineCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        return RouteGenerator.GeneratedRoute(
            polyline: MKPolyline(coordinates: coords, count: coords.count),
            totalDistance: saved.distance,
            estimatedTime: saved.estimatedTime,
            waypoints: [],
            coordinates: coords
        )
    }

    // MARK: - Default Route Name

    /// Generate default route name based on time of day
    static func defaultRouteName() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10: return "Morning Loop"
        case 10..<14: return "Midday Walk"
        case 14..<18: return "Afternoon Loop"
        case 18..<21: return "Evening Walk"
        default: return "Night Walk"
        }
    }

    // MARK: - Persistence

    private func loadRoutes() {
        guard let data = defaults.data(forKey: storageKey),
              let routes = try? JSONDecoder().decode([SavedRoute].self, from: data) else {
            return
        }
        savedRoutes = routes
    }

    private func saveRoutes() {
        guard let data = try? JSONEncoder().encode(savedRoutes) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - Private Helpers

    private func calculateCenter(of coordinates: [CoordinatePair]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        var totalLat = 0.0
        var totalLon = 0.0

        for coord in coordinates {
            totalLat += coord.latitude
            totalLon += coord.longitude
        }

        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }

    // MARK: - Debug

    #if DEBUG
    func clearAllRoutes() {
        savedRoutes = []
        defaults.removeObject(forKey: storageKey)
    }
    #endif
}
