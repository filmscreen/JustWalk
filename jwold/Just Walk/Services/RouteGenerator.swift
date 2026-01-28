//
//  RouteGenerator.swift
//  Just Walk
//
//  Generates rectangular walking routes using MKDirections.
//

import MapKit
import CoreLocation

class RouteGenerator {
    static let shared = RouteGenerator()
    private init() {}

    enum RouteError: Error, LocalizedError {
        case locationUnavailable
        case routeNotFound
        case invalidDistance
        case selfIntersecting
        case insufficientWaypoints

        var errorDescription: String? {
            switch self {
            case .locationUnavailable:
                return "Unable to get your current location"
            case .routeNotFound:
                return "Couldn't find a walkable route in this area"
            case .invalidDistance:
                return "Invalid distance specified"
            case .selfIntersecting:
                return "Route crosses itself, trying alternative"
            case .insufficientWaypoints:
                return "Couldn't generate enough waypoints for route"
            }
        }
    }

    struct GeneratedRoute {
        let polyline: MKPolyline
        let totalDistance: CLLocationDistance  // meters
        let estimatedTime: TimeInterval        // seconds
        let waypoints: [CLLocationCoordinate2D]
        let coordinates: [CLLocationCoordinate2D]
    }

    // MARK: - Public API (Completion-based for backwards compatibility)

    /// Generate a rectangular loop route
    func generateRoute(
        from start: CLLocationCoordinate2D,
        targetDistance: Double,  // miles
        completion: @escaping (Result<GeneratedRoute, RouteError>) -> Void
    ) {
        guard targetDistance > 0 else {
            completion(.failure(.invalidDistance))
            return
        }

        Task {
            do {
                let route = try await generateRouteWithRetry(
                    from: start,
                    targetDistance: targetDistance,
                    maxAttempts: 6
                )
                await MainActor.run {
                    completion(.success(route))
                }
            } catch let error as RouteError {
                await MainActor.run {
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.routeNotFound))
                }
            }
        }
    }

    // MARK: - Async API

    /// Generate route with retry logic using deterministic rotations
    func generateRouteWithRetry(
        from start: CLLocationCoordinate2D,
        targetDistance: Double,  // miles
        maxAttempts: Int = 6
    ) async throws -> GeneratedRoute {
        guard targetDistance > 0 else {
            throw RouteError.invalidDistance
        }

        // Distance compensation: walking paths are ~1.4x longer than straight-line
        let walkingMultiplier = 1.4
        let compensatedPerimeter = targetDistance / walkingMultiplier  // miles
        let sideLength = (compensatedPerimeter / 4.0) * 1609.34  // Convert to meters

        var lastError: RouteError = .routeNotFound

        for attempt in 0..<maxAttempts {
            let rotation = Double(attempt) * 15.0  // 0°, 15°, 30°, 45°, 60°, 75°

            // Generate rectangle corners with current rotation
            let corners = generateRectangleCorners(
                center: start,
                sideLength: sideLength,
                rotation: rotation
            )

            // Reorder corners to start from the nearest one (maintains clockwise order)
            let orderedCorners = reorderClockwise(corners: corners, startingNearest: start)

            do {
                let route = try await routeClockwise(from: start, through: orderedCorners)

                // Check distance tolerance (±40%)
                let actualMiles = route.totalDistance / 1609.34
                let lowerBound = targetDistance * 0.6
                let upperBound = targetDistance * 1.4

                if actualMiles < lowerBound || actualMiles > upperBound {
                    print("⚠️ Route distance (\(String(format: "%.2f", actualMiles)) mi) outside tolerance for target (\(targetDistance) mi)")
                    lastError = .routeNotFound
                    continue
                }

                // Check for self-intersection
                if routeSelfIntersects(route.coordinates) {
                    print("⚠️ Route self-intersects, trying rotation \(rotation + 15)°")
                    lastError = .selfIntersecting
                    continue
                }

                // Valid route found
                print("✓ Route generated: \(String(format: "%.2f", actualMiles)) mi with \(rotation)° rotation")
                return route

            } catch {
                print("⚠️ Routing failed for rotation \(rotation)°: \(error.localizedDescription)")
                if let routeError = error as? RouteError {
                    lastError = routeError
                }
                continue
            }
        }

        // All attempts failed
        throw lastError
    }

    // MARK: - Rectangle Corner Generation

    /// Generate 4 rectangle corners at 45°, 135°, 225°, 315° (plus rotation)
    private func generateRectangleCorners(
        center: CLLocationCoordinate2D,
        sideLength: CLLocationDistance,  // meters
        rotation: Double  // degrees
    ) -> [CLLocationCoordinate2D] {
        // Half-diagonal distance from center to corners
        let halfDiagonal = (sideLength / 2.0) * sqrt(2.0)

        // Base angles for rectangle corners (clockwise from NE)
        let baseAngles: [Double] = [45, 135, 225, 315]

        return baseAngles.map { baseAngle in
            let angle = baseAngle + rotation
            return coordinate(from: center, distance: halfDiagonal, bearing: angle)
        }
    }

    /// Reorder corners to start from the one nearest to the start point, maintaining clockwise order
    private func reorderClockwise(
        corners: [CLLocationCoordinate2D],
        startingNearest start: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard !corners.isEmpty else { return corners }

        // Find the index of the nearest corner
        var nearestIndex = 0
        var nearestDistance = start.distance(to: corners[0])

        for (index, corner) in corners.enumerated() {
            let distance = start.distance(to: corner)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestIndex = index
            }
        }

        // Rotate array to start from nearest corner
        let reordered = Array(corners[nearestIndex...]) + Array(corners[..<nearestIndex])
        return reordered
    }

    // MARK: - Sequential Routing

    /// Route through corners sequentially in clockwise order
    private func routeClockwise(
        from start: CLLocationCoordinate2D,
        through corners: [CLLocationCoordinate2D]
    ) async throws -> GeneratedRoute {
        guard !corners.isEmpty else {
            throw RouteError.insufficientWaypoints
        }

        // Build waypoint sequence: start → corner1 → corner2 → corner3 → corner4 → start
        let waypoints = [start] + corners + [start]

        var allCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: CLLocationDistance = 0
        var totalTime: TimeInterval = 0
        var routeWaypoints: [CLLocationCoordinate2D] = [start]

        // Route each segment sequentially
        for i in 0..<(waypoints.count - 1) {
            let segmentStart = waypoints[i]
            let segmentEnd = waypoints[i + 1]

            let route = try await routeSegment(from: segmentStart, to: segmentEnd)

            // Extract coordinates from this segment
            let pointCount = route.polyline.pointCount
            var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
            route.polyline.getCoordinates(&points, range: NSRange(location: 0, length: pointCount))

            // Append coordinates (drop first point on subsequent segments to avoid duplicates)
            if allCoordinates.isEmpty {
                allCoordinates.append(contentsOf: points)
            } else if points.count > 1 {
                allCoordinates.append(contentsOf: points.dropFirst())
            }

            totalDistance += route.distance
            totalTime += route.expectedTravelTime
            routeWaypoints.append(segmentEnd)
        }

        let combinedPolyline = MKPolyline(coordinates: allCoordinates, count: allCoordinates.count)

        return GeneratedRoute(
            polyline: combinedPolyline,
            totalDistance: totalDistance,
            estimatedTime: totalTime,
            waypoints: routeWaypoints,
            coordinates: allCoordinates
        )
    }

    /// Route a single segment using MKDirections
    private func routeSegment(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .walking

        let directions = MKDirections(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let route = response?.routes.first {
                    continuation.resume(returning: route)
                } else {
                    continuation.resume(throwing: RouteError.routeNotFound)
                }
            }
        }
    }

    // MARK: - Coordinate Helpers

    /// Calculate a coordinate at a given distance and bearing from an origin
    private func coordinate(
        from origin: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        bearing: Double
    ) -> CLLocationCoordinate2D {
        let bearingRadians = bearing * .pi / 180
        let distanceRadians = distance / 6_371_000

        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(distanceRadians) +
            cos(lat1) * sin(distanceRadians) * cos(bearingRadians)
        )

        let lon2 = lon1 + atan2(
            sin(bearingRadians) * sin(distanceRadians) * cos(lat1),
            cos(distanceRadians) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    // MARK: - Self-Intersection Detection

    /// Check if a route crosses itself by testing all non-adjacent segment pairs
    private func routeSelfIntersects(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count > 3 else { return false }

        // Sample every Nth point to reduce computation (routes can have thousands of points)
        let sampleRate = max(1, coordinates.count / 100)
        var sampledCoords: [CLLocationCoordinate2D] = []
        for i in stride(from: 0, to: coordinates.count, by: sampleRate) {
            sampledCoords.append(coordinates[i])
        }
        // Always include the last point
        if let last = coordinates.last,
           let sampledLast = sampledCoords.last,
           (sampledLast.latitude != last.latitude || sampledLast.longitude != last.longitude) {
            sampledCoords.append(last)
        }

        guard sampledCoords.count > 3 else { return false }

        // Check each pair of non-adjacent segments
        for i in 0..<(sampledCoords.count - 3) {
            for j in (i + 2)..<(sampledCoords.count - 1) {
                // Skip adjacent segments (they share a point)
                if j == i + 1 { continue }
                // Skip the closing segment check with first segment (they share start/end)
                if i == 0 && j == sampledCoords.count - 2 { continue }

                if segmentsIntersect(
                    sampledCoords[i], sampledCoords[i + 1],
                    sampledCoords[j], sampledCoords[j + 1]
                ) {
                    return true
                }
            }
        }
        return false
    }

    /// Check if two line segments intersect using cross product orientation
    private func segmentsIntersect(
        _ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D,
        _ p3: CLLocationCoordinate2D, _ p4: CLLocationCoordinate2D
    ) -> Bool {
        let d1 = direction(p3, p4, p1)
        let d2 = direction(p3, p4, p2)
        let d3 = direction(p1, p2, p3)
        let d4 = direction(p1, p2, p4)

        // Segments intersect if they straddle each other
        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
           ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }

        // Check for collinear cases (points on segment)
        let epsilon = 1e-10
        if abs(d1) < epsilon && onSegment(p3, p1, p4) { return true }
        if abs(d2) < epsilon && onSegment(p3, p2, p4) { return true }
        if abs(d3) < epsilon && onSegment(p1, p3, p2) { return true }
        if abs(d4) < epsilon && onSegment(p1, p4, p2) { return true }

        return false
    }

    /// Calculate the cross product direction (positive = counterclockwise, negative = clockwise)
    private func direction(
        _ p1: CLLocationCoordinate2D,
        _ p2: CLLocationCoordinate2D,
        _ p3: CLLocationCoordinate2D
    ) -> Double {
        return (p3.longitude - p1.longitude) * (p2.latitude - p1.latitude) -
               (p2.longitude - p1.longitude) * (p3.latitude - p1.latitude)
    }

    /// Check if point q lies on segment pr (when collinear)
    private func onSegment(
        _ p: CLLocationCoordinate2D,
        _ q: CLLocationCoordinate2D,
        _ r: CLLocationCoordinate2D
    ) -> Bool {
        return q.longitude <= max(p.longitude, r.longitude) &&
               q.longitude >= min(p.longitude, r.longitude) &&
               q.latitude <= max(p.latitude, r.latitude) &&
               q.latitude >= min(p.latitude, r.latitude)
    }
}

// MARK: - CLLocationCoordinate2D Extension

extension CLLocationCoordinate2D {
    /// Calculate the distance in meters to another coordinate using Haversine formula
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let earthRadius: Double = 6_371_000  // meters

        let lat1 = self.latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - self.latitude) * .pi / 180
        let deltaLon = (other.longitude - self.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }
}

// MARK: - MKPolyline Extension

extension MKPolyline {
    /// Extract coordinates from polyline
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
