//
//  SavedRoute.swift
//  Just Walk
//
//  Model for saved Magic Routes that users can walk again.
//

import Foundation

/// A saved route that the user can walk again
struct SavedRoute: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    let distance: Double  // meters
    let estimatedTime: TimeInterval  // seconds
    let polylineCoordinates: [CoordinatePair]
    let centerLatitude: Double
    let centerLongitude: Double

    // Walk stats
    var timesWalked: Int = 0
    var lastWalkedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        distance: Double,
        estimatedTime: TimeInterval,
        polylineCoordinates: [CoordinatePair],
        centerLatitude: Double,
        centerLongitude: Double,
        timesWalked: Int = 0,
        lastWalkedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.distance = distance
        self.estimatedTime = estimatedTime
        self.polylineCoordinates = polylineCoordinates
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.timesWalked = timesWalked
        self.lastWalkedAt = lastWalkedAt
    }
}

/// A coordinate pair for Codable storage
struct CoordinatePair: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}
