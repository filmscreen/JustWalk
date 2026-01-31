//
//  WalkPatternData.swift
//  JustWalk
//
//  Storage model for user pattern detection
//

import Foundation

struct WalkPatternData: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int

    // Walk timing - store last 30 walk timestamps
    var recentWalkTimes: [Date]

    // Walk type counts
    var walkTypeCounts: [String: Int]

    // Daily goal completion (last 90 days)
    var dailyGoalHistory: [String: Bool]

    // Weekly totals (last 12 weeks)
    var weeklyStepTotals: [String: Int]

    // Computed cache
    var cachedTypicalHour: Int?
    var cachedPreferredWalkType: String?
    var cachedBestDay: Int?
    var cachedHardestDay: Int?
    var cachedWeeklyTrend: TrendDirection?
    var cacheLastUpdated: Date?

    // Incremental update guards
    var lastDailyGoalRecordedDate: Date?
    var lastWeeklyTotalRecordedWeek: String?

    static let empty = WalkPatternData(
        schemaVersion: currentSchemaVersion,
        recentWalkTimes: [],
        walkTypeCounts: [:],
        dailyGoalHistory: [:],
        weeklyStepTotals: [:],
        cachedTypicalHour: nil,
        cachedPreferredWalkType: nil,
        cachedBestDay: nil,
        cachedHardestDay: nil,
        cachedWeeklyTrend: nil,
        cacheLastUpdated: nil,
        lastDailyGoalRecordedDate: nil,
        lastWeeklyTotalRecordedWeek: nil
    )
}

enum TrendDirection: String, Codable {
    case improving
    case declining
    case stable
    case insufficientData
}
