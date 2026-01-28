//
//  StreakData.swift
//  JustWalk
//
//  Core data model for streak tracking
//

import Foundation

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastGoalMetDate: Date?
    var streakStartDate: Date?
    var consecutiveGoalDays: Int // For weekly jackpot tracking (shields reset this)

    /// True when the streak has already broken (2+ day gap since last goal).
    /// Different from StreakManager.isAtRisk which means "in danger today."
    var isStreakBroken: Bool {
        guard let lastDate = lastGoalMetDate else { return false }
        return !Calendar.current.isDateInToday(lastDate) &&
               !Calendar.current.isDateInYesterday(lastDate)
    }

    static let empty = StreakData(currentStreak: 0, longestStreak: 0, lastGoalMetDate: nil, streakStartDate: nil, consecutiveGoalDays: 0)

    // Codable migration: decode consecutiveGoalDays with default 0
    init(currentStreak: Int, longestStreak: Int, lastGoalMetDate: Date?, streakStartDate: Date?, consecutiveGoalDays: Int = 0) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastGoalMetDate = lastGoalMetDate
        self.streakStartDate = streakStartDate
        self.consecutiveGoalDays = consecutiveGoalDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        lastGoalMetDate = try container.decodeIfPresent(Date.self, forKey: .lastGoalMetDate)
        streakStartDate = try container.decodeIfPresent(Date.self, forKey: .streakStartDate)
        consecutiveGoalDays = try container.decodeIfPresent(Int.self, forKey: .consecutiveGoalDays) ?? 0
    }
}
