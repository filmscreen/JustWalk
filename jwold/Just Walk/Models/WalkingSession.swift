//
//  WalkingSession.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftData

/// Represents a single walking session, including IWT (Interval Walking Technique) sessions
@Model
final class WalkingSession {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var steps: Int = 0
    var distance: Double = 0 // in meters
    var duration: TimeInterval = 0 // in seconds
    var isIWTSession: Bool = false
    var briskIntervals: Int = 0
    var slowIntervals: Int = 0
    var averagePace: Double = 0 // minutes per kilometer
    var caloriesBurned: Double = 0
    var hkWorkoutId: UUID? // HealthKit workout UUID for fetching from Health app

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        steps: Int = 0,
        distance: Double = 0,
        duration: TimeInterval = 0,
        isIWTSession: Bool = false,
        briskIntervals: Int = 0,
        slowIntervals: Int = 0,
        averagePace: Double = 0,
        caloriesBurned: Double = 0,
        hkWorkoutId: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.steps = steps
        self.distance = distance
        self.duration = duration
        self.isIWTSession = isIWTSession
        self.briskIntervals = briskIntervals
        self.slowIntervals = slowIntervals
        self.averagePace = averagePace
        self.caloriesBurned = caloriesBurned
        self.hkWorkoutId = hkWorkoutId
    }

    var isActive: Bool {
        endTime == nil
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
}
