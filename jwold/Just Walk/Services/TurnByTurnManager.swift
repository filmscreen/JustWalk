//
//  TurnByTurnManager.swift
//  Just Walk
//
//  Turn-by-turn navigation manager for Route Walk.
//  Analyzes routes to detect turns, tracks user position,
//  and provides navigation instructions with off-route detection.
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Turn Maneuver

/// Types of turn maneuvers for navigation
enum TurnManeuver: String, Codable {
    case straight
    case slightLeft
    case slightRight
    case left
    case right
    case sharpLeft
    case sharpRight
    case uTurn
    case arrival

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .straight: return "Continue straight"
        case .slightLeft: return "Slight left"
        case .slightRight: return "Slight right"
        case .left: return "Turn left"
        case .right: return "Turn right"
        case .sharpLeft: return "Sharp left"
        case .sharpRight: return "Sharp right"
        case .uTurn: return "Make a U-turn"
        case .arrival: return "Arriving"
        }
    }

    /// SF Symbol name for the maneuver
    var iconName: String {
        switch self {
        case .straight: return "arrow.up"
        case .slightLeft: return "arrow.up.left"
        case .slightRight: return "arrow.up.right"
        case .left: return "arrow.turn.up.left"
        case .right: return "arrow.turn.up.right"
        case .sharpLeft: return "arrow.turn.up.left"
        case .sharpRight: return "arrow.turn.up.right"
        case .uTurn: return "arrow.uturn.left"
        case .arrival: return "flag.checkered"
        }
    }

    /// Whether the icon should be rotated for sharp turns
    var iconRotation: Double {
        switch self {
        case .sharpLeft: return -30
        case .sharpRight: return 30
        default: return 0
        }
    }
}

// MARK: - Turn Instruction

/// A navigation instruction for an upcoming turn
struct TurnInstruction: Identifiable {
    let id = UUID()
    let maneuver: TurnManeuver
    let distanceMeters: Double      // Distance until turn
    let streetName: String?         // Optional street name
    let coordinate: CLLocationCoordinate2D

    /// Computed display distance (e.g., "In 50 ft" or "Now")
    var displayDistance: String {
        let feet = distanceMeters * 3.28084
        if feet < 30 {
            return "Now"
        } else if feet < 100 {
            return "In \(Int(round(feet / 10) * 10)) ft"
        } else if feet < 1000 {
            return "In \(Int(round(feet / 50) * 50)) ft"
        } else {
            let miles = distanceMeters / 1609.34
            if miles < 0.1 {
                return "In \(Int(round(feet / 100) * 100)) ft"
            }
            return String(format: "In %.1f mi", miles)
        }
    }

    /// Computed voice prompt for TTS
    var voicePrompt: String {
        let feet = distanceMeters * 3.28084
        let distanceText: String

        if feet < 30 {
            return "\(maneuver.displayName) now"
        } else if feet < 100 {
            distanceText = "\(Int(round(feet / 10) * 10)) feet"
        } else if feet < 200 {
            distanceText = "\(Int(round(feet / 50) * 50)) feet"
        } else if feet < 1000 {
            let roundedFeet = Int(round(feet / 100) * 100)
            distanceText = "\(roundedFeet) feet"
        } else {
            let miles = distanceMeters / 1609.34
            distanceText = String(format: "%.1f miles", miles)
        }

        // Build prompt based on maneuver type
        switch maneuver {
        case .straight:
            return "Continue straight for \(distanceText)"
        case .arrival:
            return "Approaching your starting point"
        default:
            if let street = streetName, !street.isEmpty {
                return "In \(distanceText), \(maneuver.displayName.lowercased()) onto \(street)"
            }
            return "In \(distanceText), \(maneuver.displayName.lowercased())"
        }
    }
}

// MARK: - Turn By Turn Manager

/// Main navigation manager for turn-by-turn guidance
final class TurnByTurnManager: ObservableObject {
    // MARK: - Published State

    /// Current turn instruction to display
    @Published var currentInstruction: TurnInstruction?

    /// Next turn instruction (for look-ahead)
    @Published var nextInstruction: TurnInstruction?

    /// Whether the user is off the route
    @Published var isOffRoute: Bool = false

    /// Distance in meters to the next turn
    @Published var distanceToNextTurn: Double = 0

    /// Progress along the route (0.0 to 1.0)
    @Published var routeProgress: Double = 0

    /// Whether navigation is active
    @Published var isNavigating: Bool = false

    // MARK: - Private State

    private var route: RouteGenerator.GeneratedRoute?
    private var turnInstructions: [TurnInstruction] = []
    private var currentTurnIndex: Int = 0
    private var offRouteStartTime: Date?
    private var totalRouteDistance: Double = 0
    private var distanceTraveled: Double = 0
    private var lastKnownLocation: CLLocationCoordinate2D?

    // MARK: - Configuration

    /// Distance threshold to consider user off-route (meters)
    private let offRouteThreshold: Double = 50

    /// Distance threshold to consider user back on route (meters) - hysteresis
    private let backOnRouteThreshold: Double = 30

    /// Time threshold before marking as off-route (seconds)
    private let offRouteTimeThreshold: TimeInterval = 10

    /// Distance at which to announce upcoming turn (meters)
    private let turnAnnouncementDistance: Double = 60  // ~200 ft

    /// Distance at which turn is considered "now" (meters)
    private let turnNowDistance: Double = 15  // ~50 ft

    /// Minimum angle change to detect a turn (degrees)
    private let minimumTurnAngle: Double = 25

    /// Sampling interval for turn detection (meters)
    private let turnDetectionSampleInterval: Double = 30

    // MARK: - Public Methods

    /// Start navigation for the given route
    func startNavigation(route: RouteGenerator.GeneratedRoute) {
        self.route = route
        self.totalRouteDistance = route.totalDistance
        self.isNavigating = true
        self.currentTurnIndex = 0
        self.distanceTraveled = 0
        self.routeProgress = 0
        self.isOffRoute = false
        self.offRouteStartTime = nil

        // Analyze route for turns
        turnInstructions = analyzeRouteForTurns(coordinates: route.coordinates)

        // Set initial instruction
        updateCurrentInstruction()
    }

    /// Update navigation state based on user's current location
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        guard isNavigating, let route = route else { return }

        lastKnownLocation = location

        // Find nearest point on route and distance from it
        let (nearestIndex, distanceFromRoute) = findNearestPointOnRoute(location, polyline: route.coordinates)

        // Update off-route detection
        updateOffRouteStatus(distanceFromRoute: distanceFromRoute)

        // Update progress along route
        updateRouteProgress(nearestIndex: nearestIndex, routeCoordinates: route.coordinates)

        // Update distance to next turn
        updateDistanceToNextTurn(userLocation: location, nearestIndex: nearestIndex, routeCoordinates: route.coordinates)

        // Check if we've passed the current turn
        checkTurnProgress(userLocation: location, nearestIndex: nearestIndex)
    }

    /// Stop navigation
    func stopNavigation() {
        isNavigating = false
        currentInstruction = nil
        nextInstruction = nil
        turnInstructions.removeAll()
        route = nil
        isOffRoute = false
        offRouteStartTime = nil
    }

    // MARK: - Turn Detection Algorithm

    /// Analyze route coordinates to detect turns
    private func analyzeRouteForTurns(coordinates: [CLLocationCoordinate2D]) -> [TurnInstruction] {
        guard coordinates.count >= 3 else { return [] }

        var instructions: [TurnInstruction] = []
        var previousBearing: Double?
        var accumulatedDistance: Double = 0
        var lastSampleIndex = 0

        for i in 1..<coordinates.count {
            let distance = distanceBetween(coordinates[i - 1], coordinates[i])
            accumulatedDistance += distance

            // Sample at regular intervals
            guard accumulatedDistance >= turnDetectionSampleInterval else { continue }

            // Calculate bearing from last sample point to current
            let currentBearing = calculateBearing(from: coordinates[lastSampleIndex], to: coordinates[i])

            if let prevBearing = previousBearing {
                // Calculate bearing change
                var bearingChange = currentBearing - prevBearing

                // Normalize to -180 to 180
                while bearingChange > 180 { bearingChange -= 360 }
                while bearingChange < -180 { bearingChange += 360 }

                // Detect turn if significant bearing change
                if abs(bearingChange) >= minimumTurnAngle {
                    let maneuver = detectManeuver(bearingChange: bearingChange)

                    // Calculate distance from start to this turn
                    var distanceToTurn: Double = 0
                    for j in 0..<i {
                        distanceToTurn += distanceBetween(coordinates[j], coordinates[j + 1])
                    }

                    let instruction = TurnInstruction(
                        maneuver: maneuver,
                        distanceMeters: distanceToTurn,
                        streetName: nil,
                        coordinate: coordinates[i]
                    )
                    instructions.append(instruction)
                }
            }

            previousBearing = currentBearing
            lastSampleIndex = i
            accumulatedDistance = 0
        }

        // Add arrival instruction at the end
        if let lastCoord = coordinates.last {
            let arrivalInstruction = TurnInstruction(
                maneuver: .arrival,
                distanceMeters: totalDistanceOf(coordinates),
                streetName: nil,
                coordinate: lastCoord
            )
            instructions.append(arrivalInstruction)
        }

        return instructions
    }

    /// Detect maneuver type based on bearing change
    private func detectManeuver(bearingChange: Double) -> TurnManeuver {
        let absChange = abs(bearingChange)
        let isLeft = bearingChange < 0

        switch absChange {
        case 0..<25:
            return .straight
        case 25..<55:
            return isLeft ? .slightLeft : .slightRight
        case 55..<110:
            return isLeft ? .left : .right
        case 110..<155:
            return isLeft ? .sharpLeft : .sharpRight
        default:
            return .uTurn
        }
    }

    /// Calculate bearing between two coordinates in degrees
    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }

    // MARK: - Distance Calculations

    /// Calculate distance between two coordinates in meters
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }

    /// Calculate total distance of a coordinate array
    private func totalDistanceOf(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        var total: Double = 0
        for i in 1..<coordinates.count {
            total += distanceBetween(coordinates[i - 1], coordinates[i])
        }
        return total
    }

    /// Find the nearest point on the route polyline to the given location
    private func findNearestPointOnRoute(_ point: CLLocationCoordinate2D, polyline: [CLLocationCoordinate2D]) -> (index: Int, distance: Double) {
        var minDistance = Double.infinity
        var nearestIndex = 0

        for i in 0..<polyline.count {
            let distance = distanceBetween(point, polyline[i])
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }

        return (nearestIndex, minDistance)
    }

    /// Calculate perpendicular distance from point to polyline segment
    private func distanceToPolyline(_ point: CLLocationCoordinate2D, _ polyline: [CLLocationCoordinate2D]) -> Double {
        guard polyline.count >= 2 else {
            return polyline.isEmpty ? Double.infinity : distanceBetween(point, polyline[0])
        }

        var minDistance = Double.infinity

        for i in 0..<(polyline.count - 1) {
            let segmentStart = polyline[i]
            let segmentEnd = polyline[i + 1]
            let distance = perpendicularDistance(from: point, toSegmentStart: segmentStart, segmentEnd: segmentEnd)
            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    /// Calculate perpendicular distance from point to line segment
    private func perpendicularDistance(from point: CLLocationCoordinate2D, toSegmentStart start: CLLocationCoordinate2D, segmentEnd end: CLLocationCoordinate2D) -> Double {
        let segmentLength = distanceBetween(start, end)

        if segmentLength == 0 {
            return distanceBetween(point, start)
        }

        // Project point onto line segment
        let t = max(0, min(1, (
            (point.latitude - start.latitude) * (end.latitude - start.latitude) +
            (point.longitude - start.longitude) * (end.longitude - start.longitude)
        ) / (segmentLength * segmentLength / 111320 / 111320)))  // Approximate meters to degrees

        let projectedLat = start.latitude + t * (end.latitude - start.latitude)
        let projectedLon = start.longitude + t * (end.longitude - start.longitude)
        let projected = CLLocationCoordinate2D(latitude: projectedLat, longitude: projectedLon)

        return distanceBetween(point, projected)
    }

    // MARK: - Navigation State Updates

    /// Update off-route status based on distance from route
    private func updateOffRouteStatus(distanceFromRoute: Double) {
        if isOffRoute {
            // Check if back on route (use lower threshold for hysteresis)
            if distanceFromRoute < backOnRouteThreshold {
                isOffRoute = false
                offRouteStartTime = nil
            }
        } else {
            // Check if off route
            if distanceFromRoute > offRouteThreshold {
                if offRouteStartTime == nil {
                    offRouteStartTime = Date()
                } else if let startTime = offRouteStartTime,
                          Date().timeIntervalSince(startTime) >= offRouteTimeThreshold {
                    isOffRoute = true
                }
            } else {
                offRouteStartTime = nil
            }
        }
    }

    /// Update route progress based on nearest index
    private func updateRouteProgress(nearestIndex: Int, routeCoordinates: [CLLocationCoordinate2D]) {
        guard !routeCoordinates.isEmpty else { return }

        // Calculate distance traveled to nearest index
        var traveled: Double = 0
        for i in 0..<nearestIndex {
            traveled += distanceBetween(routeCoordinates[i], routeCoordinates[i + 1])
        }

        distanceTraveled = traveled
        routeProgress = min(1.0, traveled / max(1, totalRouteDistance))
    }

    /// Update distance to the next turn
    private func updateDistanceToNextTurn(userLocation: CLLocationCoordinate2D, nearestIndex: Int, routeCoordinates: [CLLocationCoordinate2D]) {
        guard currentTurnIndex < turnInstructions.count else {
            distanceToNextTurn = 0
            return
        }

        let currentTurn = turnInstructions[currentTurnIndex]

        // Calculate distance from user to turn coordinate along the route
        distanceToNextTurn = distanceBetween(userLocation, currentTurn.coordinate)

        // Update the instruction with current distance
        if distanceToNextTurn > 0 {
            currentInstruction = TurnInstruction(
                maneuver: currentTurn.maneuver,
                distanceMeters: distanceToNextTurn,
                streetName: currentTurn.streetName,
                coordinate: currentTurn.coordinate
            )
        }
    }

    /// Check if we've passed the current turn and should advance
    private func checkTurnProgress(userLocation: CLLocationCoordinate2D, nearestIndex: Int) {
        guard currentTurnIndex < turnInstructions.count else { return }

        let currentTurn = turnInstructions[currentTurnIndex]
        let distanceToTurn = distanceBetween(userLocation, currentTurn.coordinate)

        // If we're very close to the turn or past it, advance to next
        if distanceToTurn < turnNowDistance {
            advanceToNextTurn()
        }
    }

    /// Advance to the next turn instruction
    private func advanceToNextTurn() {
        currentTurnIndex += 1
        updateCurrentInstruction()
    }

    /// Update the current and next instruction based on index
    private func updateCurrentInstruction() {
        if currentTurnIndex < turnInstructions.count {
            let turn = turnInstructions[currentTurnIndex]
            // Calculate initial distance (will be updated as user moves)
            let distanceFromStart = turn.distanceMeters - distanceTraveled
            currentInstruction = TurnInstruction(
                maneuver: turn.maneuver,
                distanceMeters: max(0, distanceFromStart),
                streetName: turn.streetName,
                coordinate: turn.coordinate
            )

            // Set next instruction if available
            if currentTurnIndex + 1 < turnInstructions.count {
                nextInstruction = turnInstructions[currentTurnIndex + 1]
            } else {
                nextInstruction = nil
            }
        } else {
            currentInstruction = nil
            nextInstruction = nil
        }
    }
}
