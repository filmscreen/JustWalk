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
    var availableShields: Int
    var todayCalories: Int
    var calorieGoal: Int?  // nil means not set

    static let empty = WatchStreakInfo(
        currentStreak: 0,
        longestStreak: 0,
        lastGoalMetDate: nil,
        dailyStepGoal: 5000,
        availableShields: 0,
        todayCalories: 0,
        calorieGoal: nil
    )

    // Codable migration: decode new fields with defaults
    init(
        currentStreak: Int,
        longestStreak: Int,
        lastGoalMetDate: Date?,
        dailyStepGoal: Int,
        availableShields: Int = 0,
        todayCalories: Int = 0,
        calorieGoal: Int? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastGoalMetDate = lastGoalMetDate
        self.dailyStepGoal = dailyStepGoal
        self.availableShields = availableShields
        self.todayCalories = todayCalories
        self.calorieGoal = calorieGoal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        lastGoalMetDate = try container.decodeIfPresent(Date.self, forKey: .lastGoalMetDate)
        dailyStepGoal = try container.decode(Int.self, forKey: .dailyStepGoal)
        availableShields = try container.decodeIfPresent(Int.self, forKey: .availableShields) ?? 0
        todayCalories = try container.decodeIfPresent(Int.self, forKey: .todayCalories) ?? 0
        calorieGoal = try container.decodeIfPresent(Int.self, forKey: .calorieGoal)
    }
}
