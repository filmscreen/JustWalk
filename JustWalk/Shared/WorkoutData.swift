//
//  WorkoutData.swift
//  JustWalk
//
//  Shared data models for workout communication between iPhone and Watch
//

import Foundation

/// Real-time workout stats sent from Watch to iPhone
struct WorkoutLiveStats: Codable {
    let walkId: UUID
    let elapsedSeconds: TimeInterval
    let heartRate: Int?           // BPM, nil if not available
    let steps: Int
    let activeCalories: Double
    let distance: Double          // meters
    let timestamp: Date
}

/// Summary data sent when workout ends
struct WorkoutSummaryData: Codable {
    let walkId: UUID
    let startTime: Date
    let endTime: Date
    let totalSeconds: TimeInterval
    let totalSteps: Int
    let totalDistance: Double     // meters
    let totalActiveCalories: Double
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let minHeartRate: Int?
    let modeRaw: String?
    let intervalProgramRaw: String?

    // Computed properties

    var durationMinutes: Int {
        Int(totalSeconds / 60)
    }

    var distanceMiles: Double {
        totalDistance / 1609.34
    }

    var distanceKilometers: Double {
        totalDistance / 1000.0
    }
}

/// Current workout state for sync
enum WorkoutState: String, Codable {
    case idle
    case active
    case paused
    case ending
}

/// Application context shared between devices
struct AppContext: Codable {
    let workoutState: WorkoutState
    let currentWalkId: UUID?
    let isPro: Bool
    let lastSyncTime: Date
}
