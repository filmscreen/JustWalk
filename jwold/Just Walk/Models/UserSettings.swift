//
//  UserSettings.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftData

/// User preferences and settings
@Model
final class UserSettings {
    var id: UUID = UUID()
    var dailyStepGoal: Int = 10000
    var iwtBriskDuration: TimeInterval = 180 // 3 minutes
    var iwtSlowDuration: TimeInterval = 180 // 3 minutes
    var enableHaptics: Bool = true
    var enableSoundCues: Bool = true
    var enableCoachingTips: Bool = true
    var strideLength: Double? // in meters, for more accurate distance
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        dailyStepGoal: Int = 10000,
        iwtBriskDuration: TimeInterval = 180,
        iwtSlowDuration: TimeInterval = 180,
        enableHaptics: Bool = true,
        enableSoundCues: Bool = true,
        enableCoachingTips: Bool = true,
        strideLength: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dailyStepGoal = dailyStepGoal
        self.iwtBriskDuration = iwtBriskDuration
        self.iwtSlowDuration = iwtSlowDuration
        self.enableHaptics = enableHaptics
        self.enableSoundCues = enableSoundCues
        self.enableCoachingTips = enableCoachingTips
        self.strideLength = strideLength
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Step goal increments (500 steps each)
    var goalIncrements: Int {
        dailyStepGoal / 500
    }

    /// Formatted brisk interval duration
    var formattedBriskDuration: String {
        let minutes = Int(iwtBriskDuration) / 60
        return "\(minutes) min"
    }

    /// Formatted slow interval duration
    var formattedSlowDuration: String {
        let minutes = Int(iwtSlowDuration) / 60
        return "\(minutes) min"
    }
}
