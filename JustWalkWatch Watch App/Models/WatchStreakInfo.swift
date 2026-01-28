//
//  WatchStreakInfo.swift
//  JustWalkWatch Watch App
//
//  Combined streak and goal info for watchOS
//

import Foundation

struct WatchStreakInfo: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastGoalMetDate: Date?
    var dailyStepGoal: Int

    static let empty = WatchStreakInfo(
        currentStreak: 0,
        longestStreak: 0,
        lastGoalMetDate: nil,
        dailyStepGoal: 5000
    )
}
