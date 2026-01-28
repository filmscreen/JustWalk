//
//  WalkSession.swift
//  Just Walk
//
//  Lightweight Codable struct for tracking active walk sessions with goal progress.
//  Shared between iPhone and Apple Watch apps.
//
//  Note: This is separate from WalkingSession (SwiftData @Model for history).
//  WalkSession tracks active walks; WalkingSession stores completed walks.
//

import Foundation
import CoreLocation

// MARK: - Codable Route Data

/// Codable version of GeneratedRoute for persistence and Watch sharing
struct GeneratedRouteData: Codable, Equatable, Hashable {
    let coordinates: [[Double]]  // [[lat, lon], ...]
    let totalDistance: Double    // meters
    let estimatedTime: TimeInterval
    let waypoints: [[Double]]    // [[lat, lon], ...]

    init(
        coordinates: [CLLocationCoordinate2D],
        totalDistance: Double,
        estimatedTime: TimeInterval,
        waypoints: [CLLocationCoordinate2D]
    ) {
        self.coordinates = coordinates.map { [$0.latitude, $0.longitude] }
        self.totalDistance = totalDistance
        self.estimatedTime = estimatedTime
        self.waypoints = waypoints.map { [$0.latitude, $0.longitude] }
    }

    init(
        coordinates: [[Double]],
        totalDistance: Double,
        estimatedTime: TimeInterval,
        waypoints: [[Double]]
    ) {
        self.coordinates = coordinates
        self.totalDistance = totalDistance
        self.estimatedTime = estimatedTime
        self.waypoints = waypoints
    }

    /// Convert back to CLLocationCoordinate2D array for map display
    var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.compactMap { arr in
            guard arr.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: arr[0], longitude: arr[1])
        }
    }

    var clWaypoints: [CLLocationCoordinate2D] {
        waypoints.compactMap { arr in
            guard arr.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: arr[0], longitude: arr[1])
        }
    }

    /// Distance in miles
    var distanceMiles: Double {
        totalDistance / 1609.34
    }
}

// MARK: - Walk Session

/// Tracks an active walk session with goal progress
struct WalkSession: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var goal: WalkGoal?
    var generatedRoute: GeneratedRouteData?

    // Progress tracking
    var currentSteps: Int = 0
    var currentDistance: Double = 0  // miles
    var currentDuration: TimeInterval = 0  // seconds

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        goal: WalkGoal? = nil,
        generatedRoute: GeneratedRouteData? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.goal = goal
        self.generatedRoute = generatedRoute
    }

    // MARK: - Goal Progress

    /// Progress towards goal (0.0 to 1.0), nil if no goal
    var goalProgress: Double? {
        guard let goal = goal, goal.type != .none else { return nil }
        switch goal.type {
        case .time:
            return min(1.0, currentDuration / 60 / goal.target)
        case .distance:
            return min(1.0, currentDistance / goal.target)
        case .steps:
            return min(1.0, Double(currentSteps) / goal.target)
        case .none:
            return nil
        }
    }

    /// Whether the goal has been reached
    var goalReached: Bool {
        guard let progress = goalProgress else { return false }
        return progress >= 1.0
    }

    /// Whether the session is still active (not ended)
    var isActive: Bool {
        endTime == nil
    }

    // MARK: - Formatted Display

    var formattedDuration: String {
        let totalSeconds = Int(currentDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        if currentDistance == floor(currentDistance) && currentDistance > 0 {
            return "\(Int(currentDistance)) mi"
        }
        return String(format: "%.2f mi", currentDistance)
    }

    var formattedSteps: String {
        return currentSteps.formatted()
    }

    // MARK: - Goal Remaining

    /// Time remaining to reach goal (in seconds), nil if not a time goal
    var timeRemaining: TimeInterval? {
        guard let goal = goal, goal.type == .time else { return nil }
        let targetSeconds = goal.target * 60
        return max(0, targetSeconds - currentDuration)
    }

    /// Distance remaining to reach goal (in miles), nil if not a distance goal
    var distanceRemaining: Double? {
        guard let goal = goal, goal.type == .distance else { return nil }
        return max(0, goal.target - currentDistance)
    }

    /// Steps remaining to reach goal, nil if not a steps goal
    var stepsRemaining: Int? {
        guard let goal = goal, goal.type == .steps else { return nil }
        return max(0, Int(goal.target) - currentSteps)
    }
}
