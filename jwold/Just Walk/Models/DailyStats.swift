//
//  DailyStats.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftData

/// Daily aggregated walking statistics
@Model
final class DailyStats {
    var id: UUID = UUID()
    var date: Date = Date()
    var totalSteps: Int = 0
    var totalDistance: Double = 0 // in meters
    var totalDuration: TimeInterval = 0 // in seconds
    var sessionsCompleted: Int = 0
    var iwtSessionsCompleted: Int = 0
    var goalReached: Bool = false
    var caloriesBurned: Double = 0

    /// Goal active when this day was recorded (nil = legacy data, backfilled on migration)
    /// This prevents goal changes from retroactively affecting past streaks.
    var historicalGoal: Int?

    /// When the step count was last calculated using the interval merge algorithm.
    /// Used for tiered caching: recent days are recalculated more frequently.
    var lastMergedAt: Date?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalSteps: Int = 0,
        totalDistance: Double = 0,
        totalDuration: TimeInterval = 0,
        sessionsCompleted: Int = 0,
        iwtSessionsCompleted: Int = 0,
        goalReached: Bool = false,
        caloriesBurned: Double = 0,
        historicalGoal: Int? = nil,
        lastMergedAt: Date? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalSteps = totalSteps
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.sessionsCompleted = sessionsCompleted
        self.iwtSessionsCompleted = iwtSessionsCompleted
        self.goalReached = goalReached
        self.caloriesBurned = caloriesBurned
        self.historicalGoal = historicalGoal
        self.lastMergedAt = lastMergedAt
    }

    /// The effective goal for this day (uses historicalGoal if set, otherwise 10k default)
    var effectiveGoal: Int {
        historicalGoal ?? 10_000
    }

    /// Progress toward goal (0.0 to 1.0+)
    var goalProgress: Double {
        Double(totalSteps) / Double(effectiveGoal)
    }

    /// Number of 500-step increments achieved
    var incrementsAchieved: Int {
        totalSteps / 500
    }

    /// Steps remaining to reach goal
    var stepsRemaining: Int {
        max(0, effectiveGoal - totalSteps)
    }

    /// Steps to next 500-step increment
    var stepsToNextIncrement: Int {
        let currentIncrement = totalSteps / 500
        let nextIncrementSteps = (currentIncrement + 1) * 500
        return nextIncrementSteps - totalSteps
    }

    var formattedDistance: String {
        let miles = totalDistance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
